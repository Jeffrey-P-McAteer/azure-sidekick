#!/bin/bash

set -e

if [ -z "$ETH_DEV" ]; then
  ETH_DEV=$(ip a | grep ': enp' | tail -1 | cut -d':' -f2 | tr -d '[:space:]')
fi
echo "ETH_DEV=$ETH_DEV"

if [ -z "$SK_USER" ] ; then
  SK_USER='jeff'
fi
echo "SK_USER=$SK_USER"

# Question one: is ethernet plugged in? If do do LAN ip config, else swap to remote
if cat "/sys/class/net/$ETH_DEV/carrier" | grep -q '1' ; then
  # Ethernet plugged in
  if ! ( ip address | grep -q 169.254.10.10 ) ; then
    sudo ip address add 169.254.10.10/16 broadcast + dev $ETH_DEV
  fi
  HOST=169.254.100.20
  PORT=22
else
  # Ethernet has no power
  HOST=sidekick.jmcateer.com
  PORT=92
fi

#HOST=169.254.100.20
#HOST=$(lanipof '00:1e:a6:00:63:22')

echo "HOST=$HOST"

ssh -i /j/ident/azure_sidekick -p $PORT "$SK_USER"@"$HOST" bash -c "'sudo mkdir -p /opt/blinkstick-controller && sudo chown -R $SK_USER /opt/blinkstick-controller'"

rsync -avz \
  -e "ssh -i /j/ident/azure_sidekick -p $PORT" \
  --exclude 'target/' \
  ./ \
  "$SK_USER"@"$HOST":/opt/blinkstick-controller

ssh -i /j/ident/azure_sidekick -p $PORT "$SK_USER"@"$HOST" bash -ic "'cd /opt/blinkstick-controller && cargo build --release'"

echo "Done!"
