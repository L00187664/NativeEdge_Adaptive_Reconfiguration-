#!/usr/bin/env bash
# enable strict mode
set -euo pipefail

# Configure variables

INPUTS_FILE="${INPUTS_FILE:-inputs.yaml}"
BLUEPRINT_ID="${BLUEPRINT_ID:-neo_vm_kiran_updated_full}"
DEPLOYMENT_BASE="${DEPLOYMENT_BASE:-my_vm_test}"
VM_IP_KEY="${VM_IP_KEY:-}"                 # can be resolved automatically
MODE="${MODE:-create_new}"                 # create_new and update_existing
INTERVAL="${INTERVAL:-10}"                 # seconds between checks when --watch is used
STATE_DIR="${STATE_DIR:-.autodeploy_state}"
LOCK_FILE="${LOCK_FILE:-$STATE_DIR/deploy.lock}"

# Keys we care about inside inputs.yaml
WATCH_KEYS_REGEX='^[[:space:]]*(cpu_vm1|memory_vm1|cpu_vm2|memory_vm2|cpu_vm3|memory_vm3)[[:space:]]*:'
# Prints help tex
usage() {
  cat <<EOF
Usage: $(basename "$0") [--watch] [--inputs path] [--blueprint id] [--deployment id] [--vm-ip-key ip] [--mode create_new|update_existing] [--interval seconds] [--lock-file path]

Defaults:
  --inputs       ${INPUTS_FILE}
  --blueprint    ${BLUEPRINT_ID}
  --deployment   ${DEPLOYMENT_BASE}
  --vm-ip-key    (auto: --vm-ip-key arg > \$VM_IP_KEY env > inputs.yaml key)
  --mode         ${MODE}
  --interval     ${INTERVAL}
  --lock-file    ${LOCK_FILE}

Examples:
  # One-shot: deploy if inputs changed (vm_ip_key read from inputs.yaml if present)
  $(basename "$0") --inputs inputs.yaml --blueprint neo_vm_kiran_updated_full --deployment my_vm_test

  # One-shot passing vm_ip_key explicitly
  $(basename "$0") --vm-ip-key 172.27.50.159

  # Watch mode, update existing deployment every time
  $(basename "$0") --watch --mode update_existing --interval 15
EOF
}

# paasing arguments
WATCH_LOOP=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --watch) WATCH_LOOP=1; shift;;
    --inputs) INPUTS_FILE="$2"; shift 2;;
    --blueprint) BLUEPRINT_ID="$2"; shift 2;;
    --deployment) DEPLOYMENT_BASE="$2"; shift 2;;
    --vm-ip-key) VM_IP_KEY="$2"; shift 2;;
    --mode) MODE="$2"; shift 2;;
    --interval) INTERVAL="$2"; shift 2;;
    --lock-file) LOCK_FILE="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1"; usage; exit 1;;
  esac
done
# checking required tools are present

ensure_tools() {
  command -v cfy >/dev/null 2>&1 || { echo "ERROR: 'cfy' CLI not found in PATH."; exit 1; }
  command -v sha256sum >/dev/null 2>&1 || { echo "ERROR: 'sha256sum' is required."; exit 1; }
  command -v grep >/dev/null 2>&1 || { echo "ERROR: 'grep' is required."; exit 1; }
  command -v sort >/dev/null 2>&1 || { echo "ERROR: 'sort' is required."; exit 1; }
  command -v flock >/dev/null 2>&1 || { echo "ERROR: 'flock' is required (util-linux)."; exit 1; }
  mkdir -p "$STATE_DIR"
}

subset_hash() {
  if [[ ! -f "$INPUTS_FILE" ]]; then
    echo "MISSING"
    return
  fi
  # hash only watched keys,Reads only the watched keys (CPU/memory) from inputs.yaml,Sorts them and hashes them with sha256sum.
  grep -E "$WATCH_KEYS_REGEX" "$INPUTS_FILE" | LC_ALL=C sort | sha256sum | awk '{print $1}'
}

state_file_path() {
  echo "$STATE_DIR/$(basename "$INPUTS_FILE").hash"
}

load_state_hash() {
  local sf; sf="$(state_file_path)"
  [[ -f "$sf" ]] && cat "$sf" || echo ""
}

save_state_hash() {
  echo "$1" > "$(state_file_path)"
}

deployment_exists() {
  cfy deployments get "$DEPLOYMENT_BASE" --json >/dev/null 2>&1
}

resolve_vm_ip_key() {
  # Priority: CLI arg to env var to inputs.yaml key
  if [[ -n "$VM_IP_KEY" ]]; then
    echo "$VM_IP_KEY"; return 0
  fi
  # Try env var first and parse from inputs.yaml
  if [[ -f "$INPUTS_FILE" ]]; then
    # Match a line like: vm_ip_key: 172.27.50.159  
    local v
    v="$(grep -E '^[[:space:]]*vm_ip_key[[:space:]]*:' "$INPUTS_FILE" | head -n1 | awk -F: '{ $1=""; sub(/^[[:space:]]*/, "", $0); print $0 }' | tr -d '"' | tr -d "'" | tr -d ' ')"
    if [[ -n "$v" ]]; then
      echo "$v"; return 0
    fi
  fi
  echo ""
}

do_create() {
  local ts dep_id vmip
  vmip="$(resolve_vm_ip_key)"
  if [[ -z "$vmip" ]]; then
    echo "ERROR: vm_ip_key not provided and not found in $INPUTS_FILE" >&2
    exit 1
  fi
  ts="$(date +%Y%m%d-%H%M%S)"
  dep_id="${DEPLOYMENT_BASE}-${ts}"
  echo
  echo ">>> Creating new deployment: $dep_id  (vm_ip_key=$vmip)"
  set -x
  cfy deployments create "$dep_id" \
    -b "$BLUEPRINT_ID" \
    -i "$INPUTS_FILE" \
    -i "vm_ip_key=$vmip"
  { set +x; } 2>/dev/null
}

do_update_or_create() {
  local vmip
  vmip="$(resolve_vm_ip_key)"
  if [[ -z "$vmip" ]]; then
    echo "ERROR: vm_ip_key not provided and not found in $INPUTS_FILE" >&2
    exit 1
  fi
  if deployment_exists; then
    echo
    echo ">>> Updating existing deployment: $DEPLOYMENT_BASE  (vm_ip_key=$vmip)"
    set -x
    cfy deployments update "$DEPLOYMENT_BASE" \
      -i "$INPUTS_FILE" \
      -i "vm_ip_key=$vmip"
    { set +x; } 2>/dev/null
  else
    echo
    echo ">>> Deployment not found. Creating: $DEPLOYMENT_BASE  (vm_ip_key=$vmip)"
    set -x
    cfy deployments create "$DEPLOYMENT_BASE" \
      -b "$BLUEPRINT_ID" \
      -i "$INPUTS_FILE" \
      -i "vm_ip_key=$vmip"
    { set +x; } 2>/dev/null
  fi
}

trigger_if_changed_once() {
  local prev new
  prev="$(load_state_hash)"
  new="$(subset_hash)"

  if [[ "$new" == "MISSING" ]]; then
    echo "WARNING: $INPUTS_FILE not found. Nothing to do."
    return 0
  fi

  if [[ -n "$prev" && "$prev" == "$new" ]]; then
    echo "No change detected in watched keys. Nothing to do."
    return 0
  fi

  echo "Change detected in inputs → starting deployment (${MODE})."
  if [[ "$MODE" == "create_new" ]]; then
    do_create
  else
    do_update_or_create
  fi
  save_state_hash "$new"
}

main_loop() {
  ensure_tools

  # Use flock so concurrent runs won't collide
  exec 9>"$LOCK_FILE"
  flock -n 9 || { echo "Another instance is running (lock: $LOCK_FILE)"; exit 0; }

  trigger_if_changed_once

  if [[ "$WATCH_LOOP" -eq 0 ]]; then
    exit 0
  fi

  echo
  echo "Watching $INPUTS_FILE for changes (keys: cpu_vm1/2/3, memory_vm1/2/3) every ${INTERVAL}s..."
  local last curr
  last="$(subset_hash)"
  while true; do
    sleep "$INTERVAL"
    curr="$(subset_hash)"
    if [[ "$curr" != "$last" && "$curr" != "MISSING" ]]; then
      echo
      echo "Detected change in inputs → deploying (${MODE})..."
      if [[ "$MODE" == "create_new" ]]; then
        do_create
      else
        do_update_or_create
      fi
      save_state_hash "$curr"
      last="$curr"
    fi
  done
}

main_loop
