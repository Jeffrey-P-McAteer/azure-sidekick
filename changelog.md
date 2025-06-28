
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
/mnt/nfs 169.254.100.20/16(rw,no_subtree_check,async,no_wdelay,all_squash,anonuid=1000,anongid=1000) 192.168.122.1/24(rw,no_subtree_check,async,no_wdelay,all_squash,anonuid=1000,anongid=1000)

```

(`192.168.122.1/24(rw)` added for default KVM VM network)

`sudo systemctl enable --now nfsv4-server.service`

`sudo systemctl enable --now rpcbind.service`

`sudo systemctl enable --now nfs-server.service`

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
  <forwarder addr='1.1.1.1'/>
</dns>

```

# 2025-06-12

About-face, we'll just add `nfsv3` and friends to our supported clients because that's the easiest way to keep our windows build client attached `-_-`

TODO

# 2025-06-15

`/periodic-commands.sh`

```bash
#!/bin/bash

if ! (virsh list | grep -q Builder-Win11) ; then
  virsh start Builder-Win11
fi



virsh setmem Builder-Win11 2048000 --live
virsh setmem Builder-MacOS 2048000 --live


exit 0
```


`/etc/modprobe.d/kvm.conf` - update to help macos boots (See https://github.com/kholia/OSX-KVM?tab=readme-ov-file#installation-preparation)

```
cat /etc/modprobe.d/kvm.conf
# Important for MacOS Guests
options kvm_amd nested=1
options kvm ignore_msrs=1 report_ignored_msrs=0
```

# 2025-06-28

Enabled Wake-On-Lan using systemd persistent config file for etherney by MAC address described here: https://wiki.archlinux.org/title/Wake-on-LAN

Also wrote a dynamic method to ensure wake-on-lan is always enabled even after a suspend-resume cycle:

`/etc/udev/rules.d/70-wol.rules`

```
ACTION=="add", SUBSYSTEM=="net", KERNEL=="en*", RUN+="/usr/bin/ethtool -s %k wol g"
```










