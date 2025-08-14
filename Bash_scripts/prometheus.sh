
#!/bin/sh
docker run -d --name prometheus \
  -p 9090:9090 \
  -v ~/prometheus-data/prometheus.yml:/etc/prometheus/prometheus.yml \
  prom/prometheus
