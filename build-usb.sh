#!/bin/bash

# Test with
#    qemu-system-x86_64 -boot d -cdrom ./out/archlinux-2025.05.24-x86_64.iso -drive file=/mnt/scratch/vms/test-disk.qcow2,format=qcow2 -m 4096 -enable-kvm

set -e

cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")"

if ! [ -e /usr/share/archiso/configs/releng/ ] ; then
  sudo pacman -S archiso
fi

device_to_write_to="$1"
if [[ -z "$device_to_write_to" ]] ; then
  echo "No disk passed as argument, select a disk to write to."
  lsblk -dno NAME,SIZE,TYPE | awk '$3=="disk" {print $1,$2}' | sed -e 's/^/\/dev\//'
  read -p "Disk: " device_to_write_to
  if [[ -z "$device_to_write_to" ]] ; then
    echo "No disk selected, exiting..."
    exit 1
  fi
  if ! [[ -e "$device_to_write_to" ]] ; then
    echo "$device_to_write_to does not exist! exiting..."
    exit 1
  fi
fi

echo "device_to_write_to=$device_to_write_to"

sudo umount /j/bins/azure-sidekick/work/x86_64/airootfs/proc || true

mkdir -p build
mkdir -p build/archiso

cp -r /usr/share/archiso/configs/releng/ build/archiso

cp auto-install.sh build/archiso/releng/airootfs/auto-install.sh
chmod +x build/archiso/releng/airootfs/auto-install.sh

cp auto-install-2.sh build/archiso/releng/airootfs/auto-install-2.sh
chmod +x build/archiso/releng/airootfs/auto-install-2.sh


cat <<'EOF' > build/archiso/releng/airootfs/etc/systemd/system/auto-install.service
[Unit]
Description=Auto run archinstall

[Service]
Type=oneshot
ExecStart=/usr/bin/bash /auto-install.sh
StandardOutput=journal
StandardError=journal
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

if [[ -L build/archiso/releng/airootfs/etc/systemd/system/multi-user.target.wants/auto-install.service ]] ; then
  rm build/archiso/releng/airootfs/etc/systemd/system/multi-user.target.wants/auto-install.service
fi
# ln -s /etc/systemd/system/auto-install.service build/archiso/releng/airootfs/etc/systemd/system/multi-user.target.wants/auto-install.service
# we now use getty1 override to do this!

cat <<'EOF' > build/archiso/releng/airootfs/auto-wifi.sh
#!/bin/bash

wifi_dev=$(iw dev | awk '$1=="Interface"{print $2; exit}')
if ! [[ -z "$wifi_dev" ]] ; then
  wpa_supplicant -B -i $wifi_dev -c <(echo -e 'network={\n ssid="MacHome 2.4ghz"\n key_mgmt=NONE\n}')

  dhclient $wifi_dev &
  dhcpcd $wifi_dev &

  sleep 1
fi

if [ -z "$ETH_DEV" ]; then
  ETH_DEV=$(ip a | grep ': enp' | tail -1 | cut -d':' -f2 | tr -d '[:space:]')
fi
if [ -z "$ETH_DEV" ]; then
  ETH_DEV=$(ip a | grep ': ens' | tail -1 | cut -d':' -f2 | tr -d '[:space:]')
fi
echo "ETH_DEV=$ETH_DEV"

if ! ( ip address | grep -q 169.254.100.20 ) ; then
  ip address add 169.254.100.20/16 broadcast + dev $ETH_DEV
  ip link set $ETH_DEV up
  ip route add 169.254.0.0/16 dev $ETH_DEV
fi

EOF

cat <<'EOF' > build/archiso/releng/airootfs/etc/systemd/system/auto-wifi.service
[Unit]
Description=Connect to WiFi

[Service]
Type=oneshot
ExecStartPre=/usr/bin/sleep 1
ExecStartPre=/usr/bin/bash /auto-wifi.sh
ExecStartPre=/usr/bin/sleep 8
ExecStart=/usr/bin/bash /auto-wifi.sh
StandardOutput=journal
StandardError=journal
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

mkdir -p 'build/archiso/releng/airootfs/etc/systemd/system/getty@tty1.service.d'
cat <<'EOF' > 'build/archiso/releng/airootfs/etc/systemd/system/getty@tty1.service.d/override.conf'
[Service]
ExecStart=
ExecStart=/usr/bin/bash /auto-install.sh
StandardInput=tty
StandardOutput=tty
Restart=always
EOF

append_line_if_not_exists() {
  if ! grep -q "$1" "$2" ; then
    echo "$1" >> "$2"
  fi
}

append_line_if_not_exists "archinstall" build/archiso/releng/packages.x86_64
append_line_if_not_exists "networkmanager" build/archiso/releng/packages.x86_64
append_line_if_not_exists "wpa_supplicant" build/archiso/releng/packages.x86_64
append_line_if_not_exists "iw" build/archiso/releng/packages.x86_64
append_line_if_not_exists "sudo" build/archiso/releng/packages.x86_64

if [[ -e work ]] ; then
  sudo rm -rf work
fi
if [[ -e out ]] ; then
  sudo rm -rf out
fi

export XZ_OPT="-T8"
export MAKEFLAGS="-j8"
sudo -E mkarchiso \
  -A 'Azure-Sidekick' \
  -L 'Azure-Sidekick' \
  -P 'jeffrey mcateer <jeffrey-bots@jmcateer.pw>' \
  -v build/archiso/releng

sync
sleep 1

sudo find . -maxdepth 3 -iname '*.iso'

iso_to_write=$(sudo find . -maxdepth 3 -iname '*.iso' | head -n 1)

echo "About to write $iso_to_write to $device_to_write_to"
read -p 'Continue?' yn

if ! grep -q -i y <<<"$yn" >/dev/null 2>&1 ; then
  echo "Aborting..."
  exit 1
fi

echo sudo dd bs=4M if="$iso_to_write" of="$device_to_write_to" conv=fsync oflag=direct status=progress
sudo dd bs=4M if="$iso_to_write" of="$device_to_write_to" conv=fsync oflag=direct status=progress

sync
sleep 1

echo "Done!"


