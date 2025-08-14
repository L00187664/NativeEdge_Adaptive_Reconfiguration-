from nativeedge import ctx
from nativeedge.exceptions import NonRecoverableError

def main():
    inputs = ctx.operation.inputs or {}
    vm_resources = inputs.get("vm_resources") or {}
    vm_ip_key = inputs.get("vm_ip_key")

    if not isinstance(vm_resources, dict):
        raise NonRecoverableError("vm_resources must be a dict mapping IP -> {cpu, memory}.")
    if not vm_ip_key:
        raise NonRecoverableError("vm_ip_key input is required (e.g., '172.27.50.159').")
    if vm_ip_key not in vm_resources:
        raise NonRecoverableError(f"vm_ip_key '{vm_ip_key}' not found in vm_resources keys: {list(vm_resources.keys())}")

    entry = vm_resources[vm_ip_key] or {}
    cpu = entry.get("cpu")
    memory = entry.get("memory")

    if cpu is None or memory is None:
        raise NonRecoverableError(f"Missing 'cpu' or 'memory' for {vm_ip_key} in vm_resources. Found: {entry}")

    # Save to runtime properties for downstream nodes
    ctx.instance.runtime_properties["selected_cpu"] = cpu
    ctx.instance.runtime_properties["selected_memory"] = memory

if __name__ == "__main__":
    main()
