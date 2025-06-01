#!/bin/sh

set -e

if [ -z "$ETH_DEV" ]; then
  ETH_DEV=$(ip a | grep ': enp' | tail -1 | cut -d':' -f2 | tr -d '[:space:]')
fi
echo "ETH_DEV=$ETH_DEV"

if ! ( ip address | grep -q 169.254.10.10 ) ; then
  sudo ip address add 169.254.10.10/16 broadcast + dev $ETH_DEV
fi

HOST=169.254.100.20
#HOST=$(lanipof '00:1e:a6:00:63:22')
#HOST=192.168.5.48

echo "HOST=$HOST"

echo "Forwarding 127.0.0.1:9000"

if ! command -v waypipe 2>&1 >/dev/null ; then
  echo "waypipe not found, running SSH directly"
  exec ssh \
    -i /j/ident/azure_sidekick \
    -L 127.0.0.1:9000:127.0.0.1:9000 \
     user@$HOST
else
  exec waypipe ssh \
    -i /j/ident/azure_sidekick \
    -L 127.0.0.1:9000:127.0.0.1:9000 \
     user@$HOST
fi
