## Bash scripts
This folder contains the Linux commands and scripts used for the various stages during the implementation.
 ### CaAdvisor.sh
  This is the Docker command used to install CaAdvisor for all the nodes.
 ### node_exporter.sh
 The Docker command used to install node_exporter for all the nodes
 ### prometheus.sh
 The Docker command is used to install Prometheus in the monitoring VM; this will pull all the data from other nodes.
 ### Grafana
 The Docker command used to install Grafana on the monitoring VM, VM will start Grafana on port 3000.
 ### OPA.sh
 Docker command used to install open policy agent on the monitoring VM, The --addr=0.0.0.0:8181 ensures OPA listens on all interfaces (not just loopback)
 ### deployment.sh
 Automatically monitors inputs.yaml for CPU/memory changes and triggers a Cloudify deployment when updates are detected.Supports one-shot or continuous watch mode,and safely prevents overlapping runs for cron scheduling.
 ### cronjobs
 This is the cron jobs created to automate the jobs
 
