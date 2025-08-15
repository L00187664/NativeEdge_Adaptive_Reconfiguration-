## YAML_Script
This readme file is created to explain the YAML files used in this project.
### prometheus.yaml 
This file contains the target IP address and service name; this will collect the logs from the targeted VMs and create the input.yaml file after evaluating the policies from OPA (adaptive.rego).
### input.yaml
This file was generated automatically based on the Python script and OPA decision and then fed to the blueprint for deployment.