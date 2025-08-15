package blueprint.adapt

# setting Thresholds limits
cpu_high := 80
cpu_low  := 20
mem_high := 80
mem_low  := 30

# setting variables
build_action(node, act) := {"node": node, "action": act}

build_action_with_res(node, act, res) := {
  "node": node,
  "action": act,
  "resource": res,
}

encoded(a) := json.marshal(a)

# Convert a set of strings into an object (k: true,)
set_to_obj(s) := { k: true | k := s[_] }

# Convenience: keys (VM names) present in input.metrics (["vm1","vm2","vm3"])
vms := object.keys(input.metrics)

# Build sets of encoded actions (no `contains`, no `some`) 

cpu_up_actions := {
  encoded(build_action_with_res(n, "scale_up", "cpu")) |
  n := vms[_];
  input.metrics[n].cpu >= cpu_high
}

cpu_down_actions := {
  encoded(build_action_with_res(n, "scale_down", "cpu")) |
  n := vms[_];
  input.metrics[n].cpu <= cpu_low
}

mem_up_actions := {
  encoded(build_action_with_res(n, "scale_up", "memory")) |
  n := vms[_];
  input.metrics[n].memory >= mem_high
}

mem_down_actions := {
  encoded(build_action_with_res(n, "scale_down", "memory")) |
  n := vms[_];
  input.metrics[n].memory <= mem_low
}

migrate_actions := {
  encoded(build_action(n, "migrate_workloads")) |
  input.nodes != null;
  n := object.keys(input.nodes)[_];
  input.nodes[n].status == 0
}

# Converting sets to objects 
o1 := set_to_obj(cpu_up_actions)
o2 := set_to_obj(cpu_down_actions)
o3 := set_to_obj(mem_up_actions)
o4 := set_to_obj(mem_down_actions)
o5 := set_to_obj(migrate_actions)

actions := object.union(object.union(object.union(object.union(o1, o2), o3), o4), o5)

