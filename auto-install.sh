#!/bin/bash

# Runs off live disk

set -e

if ! [[ -e /tmp/auto-install-has-begun ]] ; then
  touch /tmp/auto-install-has-begun
else
  read -p 'auto-install faulted; start bash instead? y/n ' yn
  if grep -q y <<<"$yn" ; then
    exec bash
  else
    echo 'Continuing...'
    sleep 1
  fi
fi

chmod +x /auto-wifi.sh
/auto-wifi.sh || true

touch /tmp/will-shutdown

locale_and_mirror_tasks() {
  timedatectl set-ntp true
  # Setup time + locale
  ln -sf /usr/share/zoneinfo/America/New_York /etc/localtime
  hwclock --systohc

  echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen
  locale-gen
  echo 'LANG="en_US.UTF-8"' > /etc/locale.conf

  # Optimize mirrors (they will be copied to the new system)
  echo 'Optimizing /etc/pacman.d/mirrorlist (running in the bg, should take 30 seconds)'
  #reflector --latest 20 --protocol http --protocol https --sort rate --save /etc/pacman.d/mirrorlist &
  sh -c 'sleep 1' # TODO move back to reflector once mirrors are more decently maintained

}

locale_and_mirror_tasks 2>/dev/null >/dev/null &
locale_and_mirror_subsh_pid=$!
echo "Forked process $locale_and_mirror_subsh_pid"
sleep 2 # for timedatectl and hwclock, that's a tad more important.

#INSTALL_DEVICE="$1"
INSTALL_DEVICE='/dev/nvme0n1'
if ! [ -z "$INSTALL_DEVICE" ] && ! [ -e "$INSTALL_DEVICE" ] && [ -e "/dev/$INSTALL_DEVICE" ] ; then
  INSTALL_DEVICE="/dev/$INSTALL_DEVICE"
fi

while [ -z "$INSTALL_DEVICE" ] || ! [ -e "$INSTALL_DEVICE" ]
do
  lsblk
  read -p "Device to install partitions to: " INSTALL_DEVICE
  if ! [ -e "$INSTALL_DEVICE" ] && [ -e "/dev/$INSTALL_DEVICE" ] ; then
    INSTALL_DEVICE="/dev/$INSTALL_DEVICE"
  fi
done

cat <<EOF

INSTALL_DEVICE=$INSTALL_DEVICE

EOF

#read -p 'About to remove partition table, continue? ' yn
# if ! grep -q y <<<"$yn" ; then
#   echo 'Exiting...'
#   exit 1
# fi

# for second runs this undoes what we did before
umount "$INSTALL_DEVICE"* || true
swapoff "$INSTALL_DEVICE"* || true

set +e
sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | fdisk ${INSTALL_DEVICE}
  g # replace the in memory partition table with an empty GPT table
  n # new partition
  1 # partition number 1
    # default - start at beginning of disk
  +2G # 2 GB boot partition
  n # new partition
  2 # partition number 2
    # default - start at beginning of disk
  +2G # 2 GB swap partition
  t # set a partition's type
  1 # select first partition
  1 # GPT id for EFI type
  t # set a partition's type
  2 # select second partition
  19 # GPT id for linux-swap (82 is for DOS disks)
  n # new partition
  3 # partion number 3
    # default, start immediately after preceding partition
    # default, extend partition to end of disk
  p # print the in-memory partition table
  w # write the partition table
  q # and we're done
EOF
set -e

echo "Done partitioning $INSTALL_DEVICE"

INSTALL_DEVICE_NAME=$(basename "$INSTALL_DEVICE")

# See https://unix.stackexchange.com/questions/226420/how-to-get-disk-name-that-contains-a-specific-partition
export LANG=en_US.UTF-8
# BOOT_PARTITION=$(lsblk | awk '/^[A-Za-z]/{d0=$1; print d0};/^[└─├─]/{d1=$1; print d0, d1};/^  [└─├─]/{d2=$1; print d0, d1, d2}' | sed 's/[├─└─]//g' | grep "$INSTALL_DEVICE_NAME" | head -n 2 | tail -n 1)
# SWAP_PARTITION=$(lsblk | awk '/^[A-Za-z]/{d0=$1; print d0};/^[└─├─]/{d1=$1; print d0, d1};/^  [└─├─]/{d2=$1; print d0, d1, d2}' | sed 's/[├─└─]//g' | grep "$INSTALL_DEVICE_NAME" | head -n 3 | tail -n 1)
# ROOT_PARTITION=$(lsblk | awk '/^[A-Za-z]/{d0=$1; print d0};/^[└─├─]/{d1=$1; print d0, d1};/^  [└─├─]/{d2=$1; print d0, d1, d2}' | sed 's/[├─└─]//g' | grep "$INSTALL_DEVICE_NAME" | tail -n 1)

BOOT_PARTITION=$(ls "$INSTALL_DEVICE"* | head -n 2 | tail -n 1)
SWAP_PARTITION=$(ls "$INSTALL_DEVICE"* | head -n 3 | tail -n 1)
ROOT_PARTITION=$(ls "$INSTALL_DEVICE"* | head -n 4 | tail -n 1)

cat <<EOF

BOOT_PARTITION=$BOOT_PARTITION
SWAP_PARTITION=$SWAP_PARTITION
ROOT_PARTITION=$ROOT_PARTITION

EOF

#yn=''
#read -p 'Does this look right, continue? ' yn
#if ! grep -q y <<<"$yn" ; then
#  echo 'Exiting...'
#  exit 1
#fi

echo 'Creating filesystems on partitions...'

mkfs.fat \
  -F32 \
  $BOOT_PARTITION

mkswap $SWAP_PARTITION

mkfs.xfs \
  -L 'Root' \
  -f \
  $ROOT_PARTITION


echo "Waiting on locale_and_mirror_subsh_pid ($locale_and_mirror_subsh_pid)..."
wait $locale_and_mirror_subsh_pid

if ! [ -e /mnt/ ] ; then
  mkdir /mnt/
fi

mount "$ROOT_PARTITION" /mnt/

mkdir -p /mnt/boot/

mount "$BOOT_PARTITION" /mnt/boot/

swapon "$SWAP_PARTITION" || true


# We now have the system mounted at /mnt/ and we are ready
# to copy packages + files in

echo 'Running pacstrap'

# Right now GPG servers are being dumb.
# Ideally we'd use pool.sks-keyservers.net but I don't know where pacman's gpg config file is.
sed -i 's/SigLevel = .*/SigLevel = Never/g' /etc/pacman.conf

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

# yn=n
# read -t 45 -p 'Update pacman keys? ' yn
# if grep -qi y <<<"$yn" ; then
#   pacman --noconfirm -Syy || true
#   pacman --noconfirm -Sy archlinux-keyring || true
#   pacman-key --init || true
#   pacman-key --populate archlinux || true
#   pacman-key --refresh-keys || true
# fi

pacstrap /mnt \
  base \
  linux \
  linux-firmware \
  sudo \
  git \
  base-devel \
  openssh \
  vim \
  dosfstools \
  btrfs-progs xfsprogs \
  iw iwd \
  zsh


echo 'Generating fstab'
genfstab -U /mnt >> /mnt/etc/fstab

echo 'Azure-Kickstart' > /mnt/etc/hostname
cat <<EOF >/mnt/etc/hosts
#<ip-address> <hostname.domain.org> <hostname>
127.0.0.1   localhost.localdomain localhost Azure-Kickstart
::1         localhost.localdomain localhost Azure-Kickstart

EOF

# Copy in wifi startup logic
cp /auto-wifi.sh /mnt/auto-wifi.sh
cp /etc/systemd/system/auto-wifi.service /mnt/etc/systemd/system/auto-wifi.service
ln -s /etc/systemd/system/auto-wifi.service /mnt/etc/systemd/system/multi-user.target.wants/auto-wifi.service

cp /auto-install-2.sh /mnt/auto-install-2.sh
chmod +x /mnt/auto-install-2.sh

arch-chroot /mnt /usr/bin/bash /auto-install-2.sh

# Make sure changes go to disk
sync

sleep 3
if [[ -e /tmp/will-shutdown ]] ; then
  shutdown now
fi
