# 🖧 XCP-ng NUT Client — Graceful UPS Shutdown Integration

This repository provides a **tested step-by-step guide** to configure a  
**NUT (Network UPS Tools) client on an XCP-ng host** for safe, automatic shutdown of all VMs and the host itself when power fails.

---

## ⚙️ 1. Prepare repositories and install packages

Log into your **XCP-ng dom0** via SSH or console.

### Update the system
```bash
yum update -y
```

### Enable EPEL repository
> The `nut-client` package depends on EPEL or extra repos.

```bash
yum --enablerepo=* install epel-release -y
```

### Install NUT packages
```bash
yum install -y nut nut-client --enablerepo=epel
```

> Installing both ensures the presence of the `nut.target` systemd unit,  
> required for `nut-monitor` to start automatically.

---

## 2. Configure the NUT client (on the XCP-ng host)

Configuration files are typically stored under `/etc/ups/`.

Create or edit the following:

### `/etc/ups/nut.conf`
```ini
MODE=netclient
```
This host acts as a **network client**.

---

### `/etc/ups/upsmon.conf`
Example configuration:
```ini
RUN_AS_USER root
MONITOR a@b 1 u p slave
#a - Name of UPS
#b - IP UPS
#u - user
#p - password

#EXAMPLE:
# MONITOR ups-number01@10.2.0.0 1 myuser randompassword slave


#Script for shutdown host
SHUTDOWNCMD "/etc/ups/xen-shutdown.sh"


MINSUPPLIES 1
POLLFREQ 5
POLLFREQALERT 5
HOSTSYNC 15
DEADTIME 25
POWERDOWNFLAG /etc/killpower
NOTIFYFLAG ONLINE SYSLOG+WALL
NOTIFYFLAG ONBATT SYSLOG+WALL
NOTIFYFLAG LOWBATT SYSLOG+WALL+EXEC
RBWARNTIME 43200
NOCOMMWARNTIME 300
FINALDELAY 5
```

**Explanation:**
- `MONITOR` defines which UPS (from the remote NUT server) this host monitors.  
  Replace IP/user/password as needed.
- `slave` marks this as a NUT client, not a master.
- `SHUTDOWNCMD` points to a shutdown script that gracefully stops VMs and powers off the host.

---

### Shutdown script — `/etc/ups/xen-shutdown.sh`
```bash
#!/bin/bash
# /etc/ups/xen-shutdown.sh

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
```

Make it executable:
```bash
chmod +x /etc/ups/xen-shutdown.sh
```

---

## 🚀 3. Enable and start NUT services
Ensure the client services are active at boot:

```bash
systemctl enable nut.target
systemctl enable nut-monitor
systemctl start nut-monitor
systemctl status nut-monitor
```

If startup fails, review logs:
```bash
journalctl -u nut-monitor -xe
```

> Without installing the full `nut` package, `nut.target` may be missing, preventing `nut-monitor` from launching.

---

## 4. Test communication with the NUT server
Run this on the **XCP-ng host (client)**:
```bash
upsc ups-number01@myuser
```

If you see UPS status details, communication works fine.

If not:
- Ensure port **3493/TCP** is open between client and server.
- Check `/etc/nut/upsd.conf` and `/etc/nut/upsd.users` on the server:
  ```ini
  [myuser]
    password = randompassword
    upsmon slave
  ```

Open the firewall port if needed:
```bash
iptables -I INPUT -p tcp --dport 3493 -j ACCEPT
service iptables save
```

---

## ⚡ 5. Test shutdown behaviour
You can **simulate a power failure** safely.

### On the XCP-ng client:
```bash
upsmon -c fsd
```

You should see:
```
Broadcast message from nut@xcp-virtual-desktops:
Executing automatic power-fail shutdown
```

The script `/etc/ups/xen-shutdown.sh` will then trigger:
1. Graceful VM shutdown  
2. Host poweroff

To confirm, check `/var/log/nut.log`.

---

## 🪪 License
[MIT License](./LICENSE)

---

## 🧰 Credits & References
- [Network UPS Tools (NUT)](https://networkupstools.org/)
- [XCP-ng Forum discussion](https://xcp-ng.org/forum/)
- Adapted and tested by **Samuel Olavo**
