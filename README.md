# NativeEdge_Adaptive_Reconfiguration
This project contains the scripts and commands used for implementing NativEdge adaptive reconfiguration as part of the MSc dissertation. For ease of access, I have split the readme files as below.

|<span style="color:green">Folder Name</span>|<span style="color:green">Readme file</span>|<span style="color:green">Comments</span>|
| --- | --- | --- |
| Bash_scripts  | BashScripts.md| All bash scripts and commands used in this project are updated here. |
| Blueprint  | Blueprint.md | This file describes the blueprint template scripts. |
| Python_scripts | python_scripts.md | All Python scripts used in this project are updated here. |
|   Rego_policies   | Rego.md | All Rego policies (OPA Decisions) used in this project are updated here.
| YAML_scripts | YAMLScript.md  | YAML scripts used in this project are updated here.

## <span style="color:green"> Blueprint Deployement</span>

Refer to the Blueprint.md for the installation; using the blueprint, create 3 virtual machines for the testing and analysis.

## <span style="color:green"> prerequisite</span>

The following softwares need to be installed on all the nodes.

1. <span style="color:Blue"> Docker</span>
3. <span style="color:Blue"> python</span>
2.  <span style="color:Blue"> cAdvisor</span>
2.  <span style="color:Blue"> node_exporter</span>

Note: All the nodes should be in same network

## <span style="color:green"> Configuration</span>

The rest of the configuration needs to be done on the NativeEdge orchestrator or a virtual machine that is created for monitoring. This VM is connected to the Dell NativeEdge orchestrator (best practice).
### <span style="color:green">Installation steps</span>


|<span style="color:green">SL NO</span>|<span style="color:green">Software Config</span>|<span style="color:green">file Name</span>|
| --- | --- | --- |
|1  | prometheus| prometheus.yml,prometheus.sh |
|2  | Grafana| grafana.sh for more info |
| 3 | OPA policy| opa.sh,rego.md for more info|
|  4   | Rego.md | All Rego policies (OPA Decisions) used in this project are updated here.
| 5| Prometheus-opa decision maker  | python.md for more info
