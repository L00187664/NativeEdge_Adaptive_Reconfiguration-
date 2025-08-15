package nativeedge.failure

# Failover intent:
# - If any node is DOWN, emit:
#     * migrate_workloads for each DOWN node
#     * scale_up (cpu) + scale_up (memory) for each UP node
# - If all nodes are UP, emit nothing (actions = {}), and action = "none"

# setting variables
build_action(node, act) := {"node": node, "action": act}

build_action_res(node, act, res) := {
  "node": node,
  "action": act,
  "resource": res,
}

encoded(a) := json.marshal(a)

# Convert a set of strings into an object 
set_to_obj(s) := { k: true | k := s[_] }

# checking keys present in input.nodes
vms := object.keys(input.nodes)

# Sets of DOWN and UP nodes (keys as provided in input.nodes)
down := { n | n := vms[_]; input.nodes[n].status == 0 }
up   := { n | n := vms[_]; input.nodes[n].status == 1 }

# Back-compat single summary:
action := "migrate_workloads" if {
  count(down) > 0
}
else := "none"

# Build sets of encoded actions
migrate_set := {
  encoded(build_action(n, "migrate_workloads")) |
  count(down) > 0;
  n := down[_]
}

cpu_up_set := {
  encoded(build_action_res(n, "scale_up", "cpu")) |
  count(down) > 0;
  n := up[_]
}

mem_up_set := {
  encoded(build_action_res(n, "scale_up", "memory")) |
  count(down) > 0;
  n := up[_]
}

# Final actions object 
actions := object.union(
  object.union(
    set_to_obj(migrate_set),
    set_to_obj(cpu_up_set),
  ),
  set_to_obj(mem_up_set),
)

