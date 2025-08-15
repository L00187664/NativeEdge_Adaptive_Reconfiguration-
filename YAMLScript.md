## YAML_Script
This readme file is created to explain the YAML files used in this project
### prometheus.yaml 
This file contain the target ip address and service name, this will collect the logs from the targeted VM's and create input.yaml file after evaluating the policies from OPA (adaptive.rego)
### input.yaml
This file generated automatically based on the python script and opa decision, and then fed to the blueprint for deplyement