#!/usr/bin/env python3
import argparse, requests, json, yaml
from datetime import datetime, timezone

# Defult settings, to fetch the logs and send to OPA
PROMETHEUS_URL = "http://localhost:9090"
OPA_URL        = "http://localhost:8181/v1/data/nativeedge/failure/actions"

# Map IPs to VM labels
TARGETS = {
    "172.27.50.159": "vm1",
    "172.27.50.160": "vm2",
    "172.27.50.161": "vm3",
}

# Default  boosted allocations
CPU_DEFAULT = 1
MEM_DEFAULT = "2048Mi"
CPU_BOOST   = 2
MEM_BOOST   = "4096Mi"

def now_utc_iso():
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

def prom_query(base_url: str, expr: str, timeout=6):
    r = requests.get(f"{base_url}/api/v1/query", params={"query": expr}, timeout=timeout)
    r.raise_for_status()
    data = r.json()
    if data.get("status") != "success":
        raise RuntimeError(f"Prometheus error: {data}")
    return data["data"]["result"]

def get_node_up(base_url: str, ip: str) -> int:
    expr = f'up{{instance="{ip}:9100"}}'
    try:
        res = prom_query(base_url, expr)
        if not res:
            return 0
        value = int(float(res[0]["value"][1]))
        return 1 if value == 1 else 0
    except Exception:
        return 0

def build_opa_input(prom_url: str):
    nodes = {ip: {"status": get_node_up(prom_url, ip)} for ip in TARGETS.keys()}
    context = {"timestamp": now_utc_iso(), "source": "prometheus"}
    return {"input": {"nodes": nodes, "context": context}}

def call_opa(opa_url: str, payload: dict) -> dict:
    r = requests.post(opa_url, json=payload, timeout=8)
    r.raise_for_status()
    return r.json().get("result", {})

def parse_actions(result: dict):
    """Return two sets: migrate_ips, boosted_ips (from encoded JSON keys)."""
    migrate_ips, boosted_ips = set(), set()
    if not isinstance(result, dict):
        return migrate_ips, boosted_ips
    for k, v in result.items():
        if not v:
            continue
        try:
            act = json.loads(k)
        except Exception:
            continue
        node = act.get("node")
        action = act.get("action", "")
        if action == "migrate_workloads" and isinstance(node, str):
            migrate_ips.add(node)
        if action == "scale_up" and isinstance(node, str):
            boosted_ips.add(node)
    return migrate_ips, boosted_ips

def write_inputs_yaml(path: str, payload: dict, boosted_ips: set):
    # start with defaults
    cpu_alloc = {label: CPU_DEFAULT for label in TARGETS.values()}
    mem_alloc = {label: MEM_DEFAULT for label in TARGETS.values()}

    # bump survivors that got scale_up actions
    boosted_labels = {TARGETS[ip] for ip in boosted_ips if ip in TARGETS}
    for lbl in boosted_labels:
        cpu_alloc[lbl] = CPU_BOOST
        mem_alloc[lbl] = MEM_BOOST

    # formatting for upload to the blueprint
    out = {
        "cpu_vm1": cpu_alloc.get("vm1", CPU_DEFAULT),
        "memory_vm1": mem_alloc.get("vm1", MEM_DEFAULT),
        "cpu_vm2": cpu_alloc.get("vm2", CPU_DEFAULT),
        "memory_vm2": mem_alloc.get("vm2", MEM_DEFAULT),
        "cpu_vm3": cpu_alloc.get("vm3", CPU_DEFAULT),
        "memory_vm3": mem_alloc.get("vm3", MEM_DEFAULT),
    }

    with open(path, "w") as f:
        yaml.safe_dump(out, f, sort_keys=False)

def main():
    ap = argparse.ArgumentParser(description="Node-failure → OPA → inputs_failover.yaml")
    ap.add_argument("--prom", default=PROMETHEUS_URL, help="Prometheus base URL")
    ap.add_argument("--opa",  default=OPA_URL,        help="OPA data URL (nativeedge/failure/actions)")
    ap.add_argument("--out",  default="inputs_failover.yaml", help="Output YAML file")
    args = ap.parse_args()

    payload = build_opa_input(args.prom)
    print("Prom→OPA Input:\n", json.dumps(payload, indent=2))

    result = call_opa(args.opa, payload)
    print("\nOPA actions:\n", json.dumps(result, indent=2))

    migrate_ips, boosted_ips = parse_actions(result)
    print("\nParsed:",
          "\n  migrate_ips:", sorted(migrate_ips),
          "\n  boosted_ips:", sorted(boosted_ips))

    write_inputs_yaml(args.out, payload, boosted_ips)
    print(f"\nWrote {args.out}")

if __name__ == "__main__":
    main()

