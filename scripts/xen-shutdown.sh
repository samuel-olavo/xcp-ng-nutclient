#!/bin/bash
# /etc/ups/xen-shutdown.sh
# Simple, reliable shutdown script for XCP-ng hosts

LOG="/var/log/nut.log"
echo "$(date '+%Y-%m-%d %H:%M:%S') - NUT: Power event received, shutting down VMs..." >> "$LOG"

# Gracefully power off all VMs except control domain
for vm in $(xe vm-list is-control-domain=false is-a-template=false params=uuid --minimal | tr ',' ' '); do
    vm_name=$(xe vm-param-get uuid=$vm param-name=name-label)
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Shutting down VM: $vm_name" >> "$LOG"
    xe vm-shutdown uuid=$vm
done

sleep 10
echo "$(date '+%Y-%m-%d %H:%M:%S') - Powering off host..." >> "$LOG"
poweroff
