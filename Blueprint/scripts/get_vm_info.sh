#!/bin/bash

while true; do
    VM_IP=$(ip -4 a s enp1s0 | awk '/inet/ {print $2}' | cut -d'/' -f1)
    if [ ! -z "$VM_IP" ]; then
        break
    fi
    echo "Waiting for VM IP address..."
    sleep 30
done

echo "The IPv4 address is: $VM_IP"

ctx instance runtime-properties capabilities.vm_host "$VM_HOST"
ctx instance runtime-properties capabilities.vm_public_ip "$VM_IP"
ctx instance runtime-properties capabilities.vm_name "$VM_NAME"
ctx instance runtime-properties capabilities.vm_username "$VM_USERNAME"
ctx instance runtime-properties capabilities.vm_ssh_port "$VM_SSH_PORT"