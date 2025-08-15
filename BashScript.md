## Bash scripts
This folder contain the linux commands and scripts used for the various stages during the implementation.
 ### CaAdvisor.sh
 This is the docker command used to install CaAdvisor for all the nodes
 ### node_exporter.sh
 Docker command used to install node_exporter for all the nodes
 ### prometheus.sh
 Docker command used to install prometheus in Monitoring VM, this will pull all the data from other nodes.
 ### Grafana
 Docker command used to install grafana on monitoring VM, this will start the grafana on port 3000
 ### OPA.sh
 Docker command used to install open policy agent on the monitoring VM, The --addr=0.0.0.0:8181 ensures OPA listens on all interfaces (not just loopback)
 ### cronjobs
 This is the cron jobs created to automate the jobs
 
