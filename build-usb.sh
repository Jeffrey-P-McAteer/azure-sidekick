#!/bin/bash

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

mkdir -p build
mkdir -p build/archiso

cp -r /usr/share/archiso/configs/releng/ build/archiso

cat <<'EOF' > build/archiso/releng/airootfs/auto-install.sh
#!/bin/bash

set -e

/auto-wifi.sh

archinstall --config /os-config.json

sync

shutdown now

EOF

chmod +x build/archiso/releng/airootfs/auto-install.sh

cp ./os-config.json build/archiso/releng/airootfs/os-config.json

cat <<'EOF' > build/archiso/releng/airootfs/etc/systemd/system/auto-install.service
[Unit]
Description=Auto run archinstall
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/auto-install.sh
StandardOutput=journal
StandardError=journal
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

echo "[Install]
WantedBy=multi-user.target" > build/archiso/releng/airootfs/etc/systemd/system/auto-install.service

if [[ -L build/archiso/releng/airootfs/etc/systemd/system/multi-user.target.wants/auto-install.service ]] ; then
  rm build/archiso/releng/airootfs/etc/systemd/system/multi-user.target.wants/auto-install.service
fi
ln -s /etc/systemd/system/auto-install.service build/archiso/releng/airootfs/etc/systemd/system/multi-user.target.wants/auto-install.service


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
echo "ETH_DEV=$ETH_DEV"

if ! ( ip address | grep -q 169.254.100.20 ) ; then
  ip address add 169.254.100.20/16 broadcast + dev $ETH_DEV
fi

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
append_line_if_not_exists "iw" build/archiso/releng/packages.x86_64

sudo mkarchiso -v build/archiso/releng

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


