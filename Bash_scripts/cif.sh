#!/bin/bash

# === Config ===
BLUEPRINT_ID="neo_vm_kiran_updated_full1"
DEPLOYMENT_ID="my_vm_test"
INPUT_FILE="inputs.yaml"
PREVIOUS_FILE="previous_inputs.yaml"

# if previous file exists
if [ ! -f "$PREVIOUS_FILE" ]; then
  echo "[INFO] No previous inputs file found. Creating new."
  cp "$INPUT_FILE" "$PREVIOUS_FILE"
  echo "[INFO] Initialising deployment..."
  cfy deployments create "$DEPLOYMENT_ID" -b "$BLUEPRINT_ID" -i "$INPUT_FILE"
  cfy executions start install -d "$DEPLOYMENT_ID"
  exit 0
fi

# Compare new vs previous
if cmp -s "$INPUT_FILE" "$PREVIOUS_FILE"; then
  echo "[INFO] No changes detected in $INPUT_FILE. Skipping deployment."
  exit 0
else
  echo "[INFO] Detected changes in $INPUT_FILE. Proceeding with update..."
  # === Step 3: Run update ===
  cfy deployments update "$DEPLOYMENT_ID" -i "$INPUT_FILE"
  if [ $? -eq 0 ]; then
    echo "[INFO] Deployment update successful."
    cp "$INPUT_FILE" "$PREVIOUS_FILE"
  else
    echo "[ERROR] Deployment update failed."
    exit 1
  fi
fi