#!/bin/bash

set -e

VM_NAME="win-ssd"

WIN_P1_PARTUUID="9d20461a-be88-41c8-a822-23c9a73835dc"
first_win_part=$(realpath "/dev/disk/by-partuuid/$WIN_P1_PARTUUID" 2>/dev/null)
win_block_device=$(lsblk -no pkname "$first_win_part" 2>/dev/null)
echo "win_block_device=$win_block_device"

ensure_vm_setup() {
  if [[ -z "$win_block_device" ]] ; then
    echo "win_block_device = $win_block_device, refusing to create VM until disk is plugged in!"
    return 1
  fi
  if ! sudo virsh list --all | grep -q "$VM_NAME" ; then
    echo "Creating $VM_NAME"
    cat >/tmp/win-ssd.xml <<EOF
<domain type='kvm'>
  <name>$VM_NAME</name>
  <memory unit='MiB'>6512</memory>
  <vcpu placement='static'>4</vcpu>
  <os>
    <type arch='x86_64' machine='pc-q35-10.0'>hvm</type>
    <loader readonly='yes' secure='yes' type='pflash' format='raw'>/usr/share/edk2/x64/OVMF_CODE.secboot.4m.fd</loader>
    <nvram template='/usr/share/edk2/x64/OVMF_VARS.4m.fd' templateFormat='raw' format='raw'>/var/lib/libvirt/qemu/nvram/${VM_NAME}_VARS.fd</nvram>
    <boot dev='hd'/>
  </os>
  <cpu mode='host-passthrough' check='none' migratable='on'>
    <topology sockets='1' dies='1' clusters='1' cores='4' threads='1'/>
  </cpu>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>destroy</on_crash>
  <pm>
    <suspend-to-mem enabled='no'/>
    <suspend-to-disk enabled='no'/>
  </pm>
  <features>
    <acpi/>
    <apic/>
    <vmport state='off'/>
  </features>
  <devices>
    <emulator>/usr/bin/qemu-system-x86_64</emulator>
    <disk type='block' device='disk'>
      <driver name='qemu' type='raw'/>
      <source dev='$win_block_device'/>
      <target dev='sda' bus='sata'/>
    </disk>
    <interface type='network'>
      <source network='default'/>
      <model type='virtio'/>
    </interface>
    <graphics type='vnc' port='-1' autoport='yes'/>
  </devices>
</domain>
EOF
    sudo virsh define /tmp/win-ssd.xml
  fi
}

shutdown_with_force() {
  if ! sudo virsh list --state-running | grep -q "$VM_NAME" ; then
    echo "shutdown_with_force is not shutting down $VM_NAME because it is not running."
    return 0
  fi
  sudo virsh shutdown "$VM_NAME" && for i in {1..90}; do
    state=$(sudo virsh domstate "$VM_NAME")
    if [[ "$state" =~ "shut off" ]]; then
        echo "$VM_NAME shut down gracefully."
        exit 0
    fi
    sleep 1
  done
  echo "$VM_NAME did not shut down in 90s, forcing power off..."
  sudo virsh destroy "$VM_NAME"
}

file_age_s() {
  local f="$1"
  if [[ -e "$f" ]]; then
    echo $(( $(date +%s) - $(stat -c %Y "$f") ))
  else
    echo 99999999
  fi
}

boot_win_ssd() {
  if ! ensure_vm_setup ; then
    echo "Failed to setup VM!"
    return 1
  fi
  if ! [[ -z "$win_block_device" ]] ; then
    win_block_device="/dev/$win_block_device"
    echo "win_block_device = $win_block_device"

    # Are we already connected to this block device?
    if ! sudo virsh dumpxml "$VM_NAME" | grep -q "$win_block_device" ; then
      echo "$VM_NAME is not using $win_block_device, shutting down and re-defining!"
      shutdown_with_force
      sync
      sleep 1
      # sudo virsh detach-disk "$VM_NAME" sda --config --persistent --live || true
      # sudo virsh attach-disk "$VM_NAME" "$win_block_device" sda --config --persistent --live --targetbus sata --driver qemu --subdriver raw
      sudo virsh detach-disk "$VM_NAME" sda --config --persistent || true
      sudo virsh attach-disk "$VM_NAME" "$win_block_device" sda --config --persistent --targetbus sata --driver qemu --subdriver raw
    else
      echo "$win_block_device is already defined for $VM_NAME"
    fi

    # Now that the disk is defined, if we are not currently running go ahead and boot up.
    if ! sudo virsh list --state-running | grep -q "$VM_NAME" ; then
      echo "Booting $VM_NAME"
      sudo touch /tmp/.win-ssd-last-boot
      sudo virsh start "$VM_NAME"
    else
      echo "$VM_NAME is already running, doing nothing."
    fi

  else
    echo "No win-ssd plugged in!"
  fi
}


# Step 1: have we boot the VM recently? We want to bring the VM up when we see the disk,
#         then later turn it off after 2 hours.
if [[ -z "$win_block_device" ]] ; then
  if [[ -e /tmp/.win-ssd-last-boot  ]] ; then
    sudo rm /tmp/.win-ssd-last-boot
  fi
else
  # Plugged in
  if [[ -e /tmp/.win-ssd-last-boot ]] ; then
    SHUTDOWN_AGE=$((2 * 3600)) # 2 hours
    BOOT_AGAIN_AGE=$((24 * 3600)) # 24 hours
    AGE=$(file_age_s /tmp/.win-ssd-last-boot)
    if (( AGE > BOOT_AGAIN_AGE )); then
      # Booted > 24 hours ago, request a boot up
      boot_win_ssd
    else
      if (( AGE > SHUTDOWN_AGE )); then
        # Booted > 2 hours ago, request a graceful shutdown
        sudo virsh shutdown "$VM_NAME"
      fi
    fi
  else
    # Have not booted yet, boot!
    boot_win_ssd
  fi
fi




