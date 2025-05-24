#!/bin/bash

# Part 2 of the install:
# this file is copied to /mnt/
# and executed inside the newly installed system
# using arch-chroot

set -e

# Setup time + locale
ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime
hwclock --systohc

echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen
locale-gen
echo 'LANG="en_US.UTF-8"' > /etc/locale.conf

# Cannot run in chroot; TODO install-pt3.sh?
timedatectl set-ntp true || true

echo 'Azure-Sidekick' > /etc/hostname
# hostname 'Azure-Sidekick'

# Just in case pacstrap didn't already do this
mkinitcpio -P

# Bootloader
bootctl --esp-path=/boot/ install

# Package + signing stuff
mkdir -p /etc/pacman.d/gnupg
if ! [ -e /etc/pacman.d/gnupg/gpg.conf ] || ! grep -q "hkp://keyserver.ubuntu.com" </etc/pacman.d/gnupg/gpg.conf ; then
  echo 'keyserver hkp://keyserver.ubuntu.com' >> /etc/pacman.d/gnupg/gpg.conf
fi
mkdir -p /root/.gnupg/
if ! [ -e /root/.gnupg/gpg.conf ] || ! grep -q "hkp://keyserver.ubuntu.com" </root/.gnupg/gpg.conf ; then
  echo 'keyserver hkp://keyserver.ubuntu.com' >> /root/.gnupg/gpg.conf
fi

cat <<EOF > /etc/pacman.d/mirrorlist
##
## Arch Linux repository mirrorlist
## Filtered by mirror score from mirror status page
## Generated on 2025-05-24
##

Server = https://us.arch.niranjan.co/\$repo/os/\$arch
Server = https://arlm.tyzoid.com/\$repo/os/\$arch
Server = https://mirrors.iu13.net/archlinux/\$repo/os/\$arch
Server = https://zxcvfdsa.com/arch/\$repo/os/\$arch
Server = https://mirrors.lug.mtu.edu/archlinux/\$repo/os/\$arch
Server = https://mirrors.bjg.at/arch/\$repo/os/\$arch
Server = https://m.lqy.me/arch/\$repo/os/\$arch
Server = https://coresite.mm.fcix.net/archlinux/\$repo/os/\$arch
Server = https://mirror.clarkson.edu/archlinux/\$repo/os/\$arch
Server = https://mirrors.ocf.berkeley.edu/archlinux/\$repo/os/\$arch
Server = https://mirrors.kernel.org/archlinux/\$repo/os/\$arch
Server = https://mirrors.mit.edu/archlinux/\$repo/os/\$arch
Server = https://archmirror1.octyl.net/\$repo/os/\$arch
Server = https://mirrors.smeal.xyz/arch-linux/\$repo/os/\$arch
Server = https://arch.mirror.marcusspencer.us:4443/archlinux/\$repo/os/\$arch
Server = https://mnvoip.mm.fcix.net/archlinux/\$repo/os/\$arch
Server = https://mirror.fcix.net/archlinux/\$repo/os/\$arch
Server = https://arch.miningtcup.me/\$repo/os/\$arch
Server = https://forksystems.mm.fcix.net/archlinux/\$repo/os/\$arch
Server = https://mirror.akane.network/archmirror/\$repo/os/\$arch
Server = https://southfront.mm.fcix.net/archlinux/\$repo/os/\$arch
Server = https://yonderly.org/mirrors/archlinux/\$repo/os/\$arch
Server = https://ziply.mm.fcix.net/archlinux/\$repo/os/\$arch
Server = https://nocix.mm.fcix.net/archlinux/\$repo/os/\$arch
Server = https://mirror.givebytes.net/archlinux/\$repo/os/\$arch
Server = https://mirror.arizona.edu/archlinux/\$repo/os/\$arch
Server = https://ohioix.mm.fcix.net/archlinux/\$repo/os/\$arch
Server = https://mirror.umd.edu/archlinux/\$repo/os/\$arch
Server = https://mirror.colonelhosting.com/archlinux/\$repo/os/\$arch
Server = https://repo.ialab.dsu.edu/archlinux/\$repo/os/\$arch
Server = https://losangeles.mirror.pkgbuild.com/\$repo/os/\$arch
Server = https://mirrors.shr.cx/arch/\$repo/os/\$arch
Server = https://us.mirrors.cicku.me/archlinux/\$repo/os/\$arch
Server = https://irltoolkit.mm.fcix.net/archlinux/\$repo/os/\$arch
Server = https://us-mnz.soulharsh007.dev/archlinux/\$repo/os/\$arch
Server = https://ftp.osuosl.org/pub/archlinux/\$repo/os/\$arch
Server = https://arch.goober.cloud/\$repo/os/\$arch
Server = https://ord.mirror.rackspace.com/archlinux/\$repo/os/\$arch
Server = https://mirror.ette.biz/archlinux/\$repo/os/\$arch
Server = https://mirror.wdc1.us.leaseweb.net/archlinux/\$repo/os/\$arch
Server = https://mirror.sfo12.us.leaseweb.net/archlinux/\$repo/os/\$arch
Server = https://mirrors.rit.edu/archlinux/\$repo/os/\$arch
Server = https://mirrors.bloomu.edu/archlinux/\$repo/os/\$arch
Server = https://arch-mirror.brightlight.today/\$repo/os/\$arch
Server = https://mirrors.sonic.net/archlinux/\$repo/os/\$arch
Server = https://arch.mirror.k0.ae/\$repo/os/\$arch
Server = https://mirror.pit.teraswitch.com/archlinux/\$repo/os/\$arch
Server = https://mirror.pilotfiber.com/archlinux/\$repo/os/\$arch
Server = https://arch.hu.fo/archlinux/\$repo/os/\$arch
Server = https://iad.mirrors.misaka.one/archlinux/\$repo/os/\$arch
Server = https://nnenix.mm.fcix.net/archlinux/\$repo/os/\$arch
Server = https://mirror.adectra.com/archlinux/\$repo/os/\$arch
Server = https://mirror.zackmyers.io/archlinux/\$repo/os/\$arch
Server = https://america.mirror.pkgbuild.com/\$repo/os/\$arch
Server = https://codingflyboy.mm.fcix.net/archlinux/\$repo/os/\$arch
Server = https://opencolo.mm.fcix.net/archlinux/\$repo/os/\$arch
Server = https://mirrors.xtom.com/archlinux/\$repo/os/\$arch
Server = https://mirror.hasphetica.win/archlinux/\$repo/os/\$arch
Server = https://mirrors.lahansons.com/archlinux/\$repo/os/\$arch
Server = https://mirrors.vectair.net/archlinux/\$repo/os/\$arch
Server = https://dfw.mirror.rackspace.com/archlinux/\$repo/os/\$arch
Server = https://arch.mirror.constant.com/\$repo/os/\$arch
Server = https://mirror.theash.xyz/arch/\$repo/os/\$arch
Server = https://volico.mm.fcix.net/archlinux/\$repo/os/\$arch
Server = https://plug-mirror.rcac.purdue.edu/archlinux/\$repo/os/\$arch
Server = https://iad.mirror.rackspace.com/archlinux/\$repo/os/\$arch
Server = https://ridgewireless.mm.fcix.net/archlinux/\$repo/os/\$arch

EOF

# yn=''
# read -t 45 -p 'Update pacman keys? ' yn
# if grep -qi y <<<"$yn" ; then
#   pacman --noconfirm -Syy || true
#   pacman --noconfirm -Sy archlinux-keyring || true
#   yes | pacman-key --init || true
#   yes | pacman-key --populate archlinux || true
#   yes | pacman-key --refresh-keys || true
# fi

pacman --noconfirm -Syy || true
pacman --noconfirm -Sy archlinux-keyring || true
yes | pacman-key --init || true
yes | pacman-key --populate archlinux || true
yes | pacman-key --refresh-keys || true

# Enable some systemd tasks
ln -nsf /usr/lib/systemd/system/systemd-networkd.service /etc/systemd/system/multi-user.target.wants/
ln -nsf /usr/lib/systemd/system/systemd-resolved.service /etc/systemd/system/multi-user.target.wants/

# We do the symlinking before moving into the new OS
# if [ -e /etc/resolv.conf ] ; then
#   rm /etc/resolv.conf
# fi
# ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

pacman -S --noconfirm systemd-resolvconf # replaces /usr/bin/resolvconf with systemd so it can manage 3rdparty requests
if ! grep 127 /etc/resolv.conf ; then
  cat <<EOF >>/etc/resolv.conf
nameserver 127.0.0.53
options edns0 trust-ad

EOF
fi

# Create user "user"
useradd \
  --home /home/user \
  --shell /bin/zsh \
  --groups wheel,lp \
  -m user || true

echo 'user:S1deK1ck' | chpasswd
echo 'root:S1deK1ck' | chpasswd

if ! [ -e /etc/sudoers.d/user ] ; then
  cat <<EOJC > /etc/sudoers.d/user
user ALL=(ALL) ALL
Defaults:user timestamp_timeout=9000
Defaults:user !tty_tickets

user ALL=(ALL) NOPASSWD: ALL
EOJC

fi

# Grant root rights to ALL (this is removed at the end)
echo 'root ALL = (ALL) NOPASSWD: ALL' > /etc/sudoers.d/installstuff

# Add autologin for user user
mkdir -p '/etc/systemd/system/getty@tty1.service.d'
cat <<EOF >/etc/systemd/system/getty@tty1.service.d/override.conf
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin user --noclear %I \$TERM

EOF


# Install deps to makepkg
pacman -S --noconfirm base-devel git

# use user user to install yay

(
  cd /opt
  git clone https://aur.archlinux.org/yay-git.git
  chown -R user:user yay-git
  cd /opt/yay-git
  sudo -u user makepkg -si --noconfirm
)


# use yay to install neat sw

echo 'WARNING: lots of apps going in'
sleep 1.5

sidekick_packages=(
  # Kernel stuff
  linux-headers # for DKMS drivers
  intel-ucode
  amd-ucode
  i915-firmware
  util-linux

  ## terminals
  zsh oh-my-zsh-git

  ## cli utilities
  tree
  python python-pip
  htop
  powerline powerline-fonts
  powerline-console-fonts
  curl wget
  lshw
  net-tools
  nmap
  imagemagick
  efibootmgr

  ## Extra sw dev tools
  mold-git
  gdb
  vmtouch

  # Language support
  dotnet-sdk

  cifs-utils
  archiso

  # GPU nonsense
  bolt
  vulkan-intel xf86-video-intel xf86-video-amdgpu xf86-video-nouveau xf86-video-ati
  vulkan-radeon mesa mesa-vdpau
  displaylink xf86-video-fbdev
  libva-mesa-driver
  opencl-amd vulkan-amdgpu-pro vulkan-tools
  nvidia cuda
  intel-media-driver intel-compute-runtime level-zero-loader

  rsync
  iw
  wireless_tools

)

for i in "${!sidekick_packages[@]}"; do
  echo "Installing ${sidekick_packages[$i]} ($i of ${#sidekick_packages[@]})"
  sudo -u user yay -S \
    --noconfirm --answerdiff=None \
    "${sidekick_packages[$i]}" || true
done

cat <<EOF >/etc/systemd/logind.conf
#  This file is part of systemd.
#
#  systemd is free software; you can redistribute it and/or modify it
#  under the terms of the GNU Lesser General Public License as published by
#  the Free Software Foundation; either version 2.1 of the License, or
#  (at your option) any later version.
#
# Entries in this file show the compile time defaults.
# You can change settings by editing this file.
# Defaults can be restored by simply deleting this file.
#
# See logind.conf(5) for details.

[Login]
#NAutoVTs=6
#ReserveVT=6
#KillUserProcesses=no
#KillOnlyUsers=
#KillExcludeUsers=root
#InhibitDelayMaxSec=5
#HandlePowerKey=poweroff
#HandleSuspendKey=suspend
#HandleHibernateKey=hibernate
#HandleLidSwitch=suspend
#HandleLidSwitchExternalPower=suspend
#HandleLidSwitchDocked=ignore
#PowerKeyIgnoreInhibited=no
#SuspendKeyIgnoreInhibited=no
#HibernateKeyIgnoreInhibited=no
#LidSwitchIgnoreInhibited=yes
#HoldoffTimeoutSec=30s
#IdleAction=ignore
#IdleActionSec=30min
#RuntimeDirectorySize=10%
#RuntimeDirectoryInodes=400k
#RemoveIPC=yes
#InhibitorsMax=8192
#SessionsMax=8192

HandleLidSwitch=ignore

EOF

systemctl enable iwd || true

# Add boot entry
ROOT_PARTUUID=$(blkid | grep -i 'Root' | sed 's/.*PARTUUID="//g' | sed 's/".*//g' | tr -d '\n')
echo "ROOT_PARTUUID=$ROOT_PARTUUID"

cat <<EOF >/boot/loader/entries/azure-sidekick.conf
title Azure Sidekick
linux /vmlinuz-linux
#initrd /intel-ucode.img
#initrd /amd-ucode.img
initrd /initramfs-linux.img
options root=PARTUUID=$ROOT_PARTUUID rootfstype=xfs add_efi_memmap mitigations=off pti=off intel_pstate=passive

EOF

cat <<EOF >/boot/loader/loader.conf
#console-mode keep
console-mode max
timeout 2
default azure-sidekick.conf
EOF

# install rust in user's account
sudo -u user sh -c "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y" || true

# Install zig
yay -S zig

# Config stuff
sudo -u user git config --global core.preloadIndex true || true

# Add user to useful groups
added_groups=(
  video
  audio
  disk
  avahi
  cups
  power
  radicale
  xpra
  uucp
  optical
  lp
  input
  # Copy-pasted in from prior install, TODO sort/organize
  root bin daemon sys tty mem ftp mail log smmsp proc http games lock uuidd dbus network floppy scanner power polkitd rtkit usbmux nvidia-persistenced wireshark transmission rabbitmq cups seat adbusers i2c qemu libvirt-qemu systemd-oom sgx brltty jabber tss gnupg-pkcs11-scd-proxy gnupg-pkcs11 dhcpcd libvirt _telnetd xpra radicale brlapi colord avahi git systemd-coredump systemd-timesync systemd-resolve systemd-network systemd-journal-remote rfkill systemd-journal users video uucp storage render optical lp kvm input disk audio utmp kmem wheel adm jeffrey dialout plugdev nobody
)
for g in "${added_groups[@]}" ; do
  echo "Adding user to $g"
  usermod -a -G $g user || true
done

# Make sure jeff can access his own stuff
chown -R user:user /home/user

# Remove rights we granted root earlier; yeah it's stupid but we're being civilized here.
rm /etc/sudoers.d/installstuff || true

# Sync changes
sync

cat <<EOF

DONE!

EOF


