
# 2025-06-01

Setup an NFS share using /dev/sda1 as backing storage w/ an XFS filesystem. Basically a copy-paste of this w/ the azure-* IPs: https://wiki.archlinux.org/title/NFS

`fstab` got a new line:

```
# /dev/sda1
UUID=a39848c6-c24b-4b0e-9960-7900665410b9  /mnt/nfs  xfs    rw,relatime,nofail,gid=1000,uid=1000          0 0
```

`yay -S nfs-utils`


`/etc/exports` contains

```
/mnt/nfs 169.254.100.20/16(rw)

```

`sudo systemctl enable --now nfsv4-server.service`


# 2025-06-10

Setup `cockpit` along with some VM stuff to do VMs from a browser.

`sudo pacman -Syu cockpit cockpit-machines qemu-full virt-manager virt-viewer dnsmasq bridge-utils libvirt swtpm edk2-ovmf`


`sudo systemctl enable --now cockpit.socket`

`sudo systemctl enable --now libvirtd`

`sudo usermod -aG libvirt $(whoami)`


`sudo systemctl edit cockpit.socket`

```
[Socket]
# Clear the default ListenStream
ListenStream=

# Add your specific IP
ListenStream=169.254.100.20:9090
```

Management available at `https://169.254.100.20:9090`, `user:S1deK1ck`

`sudo mkdir /mnt/nfs/vm-storage-pool` << added storage pool


Create `/etc/systemd/system/periodic-commands.timer`

```
[Unit]
Description=Run various commands every 15 minutes

[Timer]
OnBootSec=5min
OnUnitActiveSec=15min
Unit=periodic-commands.service

[Install]
WantedBy=timers.target
````


Create `/etc/systemd/system/periodic-commands.service`

```
[Unit]
Description=Run various commands every 15 minutes

[Service]
Type=oneshot
ExecStart=/usr/bin/bash /periodic-commands.sh
````

```
sudo systemctl daemon-reload
sudo systemctl enable --now periodic-commands.timer
```

For the windows VM particularly:

```
sudo EDITOR=vim virsh edit Builder-Win11
# Under <devices> add
<tpm model='tpm-crb'>
  <backend type='emulator' version='2.0'/>
</tpm>

```


```
echo "net.ipv4.ip_forward = 1" | sudo tee /etc/sysctl.d/99-forwarding.conf
````

```
sudo EDITOR=vim virsh net-edit default
Under <network> add/update

<dns>
  <forwarder addr='127.0.0.53'/>
</dns>

```


