#!/usr/bin/env python3
import argparse, requests, json, yaml, sys
from urllib.parse import urljoin

# Defaults configuration, calling prometheus and OPA
DEFAULT_PROM = "http://localhost:9090"
DEFAULT_OPA  = "http://localhost:8181/v1/data/blueprint/adapt/actions"
# Map vm names to Prometheus instances (<ip>:9100)
VM_INSTANCE_MAP = {
    "vm1": "172.27.50.159:9100",
    "vm2": "172.27.50.160:9100",
    "vm3": "172.27.50.161:9100",
}
# Prometheus CPU window
DEFAULT_WINDOW = "1m"

# Allocation mappings from OPA actions to final blueprint values
CPU_DEFAULT  = 1
MEM_DEFAULT  = "2048Mi"
CPU_MAP = {
    "scale_up": 4,
    "scale_down": 2,
    "none": CPU_DEFAULT,
}
MEM_MAP = {
    "scale_up": "4096Mi",
    "scale_down": "2048Mi",
    "none": MEM_DEFAULT,
}

# Calculating average cpu and memory 

def q(prom_url, expr):
    r = requests.get(
        urljoin(prom_url, "/api/v1/query"),
        params={"query": expr},
        timeout=10,
    )
    r.raise_for_status()
    data = r.json()
    if data.get("status") != "success":
        raise RuntimeError(f"Bad Prometheus response: {data}")
    return data["data"]["result"]

def get_cpu_percent_by_instance(prom_url, window):
    # Avg CPU utilization % across all cores: 100 * (1 - idle%)
    expr = f'100 * (1 - avg by(instance) (rate(node_cpu_seconds_total{{mode="idle"}}[{window}])))'
    result = q(prom_url, expr)
    cpu = {}
    for series in result:
        inst = series["metric"].get("instance")
        val = float(series["value"][1])
        cpu[inst] = val
    return cpu  # { "ip:9100": 37.2, ... }

def get_mem_percent_by_instance(prom_url):
    # Memory used %: 100 * (1 - MemAvailable / MemTotal)
    expr = '100 * (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes))'
    result = q(prom_url, expr)
    mem = {}
    for series in result:
        inst = series["metric"].get("instance")
        val = float(series["value"][1])
        mem[inst] = val
    return mem

def build_opa_input(prom_url, window, vm_map):
    cpu_by_inst = get_cpu_percent_by_instance(prom_url, window)
    mem_by_inst = get_mem_percent_by_instance(prom_url)

    metrics = {}
    for vm, inst in vm_map.items():
        cpu = cpu_by_inst.get(inst)
        mem = mem_by_inst.get(inst)
        # If a metric is missing, fall back to 0 so OPA can decide
        if cpu is None:
            cpu = 0.0
        if mem is None:
            mem = 0.0
        metrics[vm] = {
            "cpu": round(cpu, 2),
            "memory": round(mem, 2),
        }

    return {"input": {"metrics": metrics}}

def call_opa(opa_url, payload):
    r = requests.post(opa_url, json=payload, timeout=10)
    r.raise_for_status()
    return r.json().get("result", {})

def decide_allocations(opa_result, vm_names):
    # Defaults
    cpu_alloc = {vm: CPU_DEFAULT for vm in vm_names}
    mem_alloc = {vm: MEM_DEFAULT for vm in vm_names}

    # Expecting result like: { "<encoded action json>": true/false, ... }
    for encoded, approved in opa_result.items():
        if not approved:
            continue
        try:
            action = json.loads(encoded)
        except Exception:
            # If the key isn't JSON, skip gracefully
            continue

        node = action.get("node")
        act  = action.get("action", "").lower()
        resource = action.get("resource")  # may be None

        if node not in cpu_alloc:
            continue  # unknown target

        # Heuristics to classify action to CPU vs Memory
        is_mem = (resource == "memory") or ("mem" in act)
        if is_mem:
            # Normalize action to map keys
            key = "scale_up" if "up" in act else ("scale_down" if "down" in act else "none")
            mem_alloc[node] = MEM_MAP.get(key, MEM_DEFAULT)
        else:
            key = "scale_up" if "up" in act else ("scale_down" if "down" in act else "none")
            cpu_alloc[node] = CPU_MAP.get(key, CPU_DEFAULT)

    return cpu_alloc, mem_alloc

def write_inputs_yaml(path, cpu_alloc, mem_alloc):
    out = {}
    # Flatten to the blueprint naming convention: cpu_vmX, memory_vmX
    for vm in sorted(cpu_alloc.keys()):
        out[f"cpu_{vm}"] = cpu_alloc[vm]
        out[f"memory_{vm}"] = mem_alloc[vm]
    with open(path, "w") as f:
        yaml.safe_dump(out, f, sort_keys=True)

def main():
    ap = argparse.ArgumentParser(description="Query Prometheus to OPA to generate inputs.yaml (CPU + memory).")
    ap.add_argument("--prom", default=DEFAULT_PROM, help="Prometheus base URL")
    ap.add_argument("--opa", default=DEFAULT_OPA, help="OPA data API URL for actions")
    ap.add_argument("--window", default=DEFAULT_WINDOW, help="Prometheus rate window (e.g., 1m, 5m)")
    ap.add_argument("--out", default="inputs.yaml", help="Output YAML path")
    args = ap.parse_args()

    try:
        opa_input = build_opa_input(args.prom, args.window, VM_INSTANCE_MAP)
    except Exception as e:
        print(f"ERROR: failed to build OPA input from Prometheus: {e}", file=sys.stderr)
        sys.exit(2)

    try:
        result = call_opa(args.opa, opa_input)
    except Exception as e:
        print(f"ERROR: OPA decision call failed: {e}", file=sys.stderr)
        print("OPA input was:", json.dumps(opa_input, indent=2))
        sys.exit(3)

    cpu_alloc, mem_alloc = decide_allocations(result, vm_names=list(VM_INSTANCE_MAP.keys()))

    try:
        write_inputs_yaml(args.out, cpu_alloc, mem_alloc)
    except Exception as e:
        print(f"ERROR: failed to write {args.out}: {e}", file=sys.stderr)
        sys.exit(4)

    print("OPA input (metrics):")
    print(json.dumps(opa_input, indent=2))
    print("\nOPA decision (raw):")
    print(json.dumps(result, indent=2))
    print(f"\nWrote {args.out} with allocations:")
    for vm in sorted(cpu_alloc.keys()):
        print(f"  {vm}: cpu={cpu_alloc[vm]}, memory={mem_alloc[vm]}")

if __name__ == "__main__":
    main()

