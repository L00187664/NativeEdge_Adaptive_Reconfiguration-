## Blueprint Folder
This folder contains the blueprint scripts used to deploy the VM on the Dell NativeEdge infrastructure. The main template was downloaded from the Dell official repository and customised to fit into our environment. All these scripts are packed in a zip folder before upload to the NE.

### wget_blueprint_updated.yml
This is the main blueprint. It imports the virtual_machine.yaml file, which contains reusable node templates for VM provisioning. After the VM provisioning, the blueprint runs the other scripts inside the 'script' folder.
###  virtual_machine.yaml
Defines the building blocks used by the main blueprint to create or reference a VM and attach lifecycle/config steps. It handles the binary image, default user, SSH keys, VM name, public IP address, etc.
### input.yaml
These are the resource values which are used to drive the deployment. The blueprint reads this file and updates the resources based on the values in it.based on the values in it.
### scripts/prepare_resource_config.py
Render the YAML template into a concrete configuration using provided parameters. (DHCP vs static IP, gateway, etc.) 
### scripts/get_vm_info.sh
Runs on the VM to detect the IPv4 address of enp1s0, then writes several values (host, public_ip, name, username, ssh_port) into the instance runtime properties.
### scripts/verify_tags.py
A pre-validation check that service tags (likely NativeEdge/PowerEdge iDRAC service tags or logical labels) are unique when verify_tags: true.
### scripts/check_drift.py
A drift detector stub that always returns {'drift': True}
### scripts/wget.sh
A demo “post-provision” action: refresh apt, create a folder, download Harbour 2.5.0, and extract it. It illustrates running arbitrary automation on the VM after provisioning..
