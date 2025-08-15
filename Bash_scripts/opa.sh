#!/bin/sh
docker run -d --name opa \
  -p 8181:8181 \
  openpolicyagent/opa:latest \
  run --server --addr=0.0.0.0:8181
