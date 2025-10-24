#!/bin/bash
# /etc/ups/xen-shutdown.sh
# --------------------------------------------
# Author:  Samuel Olavo
# --------------------------------------------

LOG="/var/log/nut.log"

echo "$(date '+%Y-%m-%d %H:%M:%S') - NUT: Power event received, initiating VM shutdown sequence..." >> "$LOG"

# Get all VMs except control domain (dom0) and templates
VM_LIST=$(xe vm-list is-control-domain=false is-a-template=false params=uuid --minimal | tr ',' ' ')

for vm in $VM_LIST; do
    vm_name=$(xe vm-param-get uuid=$vm param-name=name-label)
    vm_state=$(xe vm-param-get uuid=$vm param-name=power-state)

    # Only shut down running VMs
    if [ "$vm_state" = "running" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Shutting down VM: $vm_name" >> "$LOG"
        xe vm-shutdown uuid=$vm >/dev/null 2>&1
        sleep 5  # Give it a few seconds between shutdowns
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Skipping VM (already halted): $vm_name" >> "$LOG"
    fi
done

# Wait a bit before shutting down the host
sleep 10
echo "$(date '+%Y-%m-%d %H:%M:%S') - All VMs processed. Powering off host..." >> "$LOG"
poweroff

# End of script
