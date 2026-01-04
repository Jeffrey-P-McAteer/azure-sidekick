#!/bin/sh

set -e

if [ -z "$ETH_DEV" ]; then
  ETH_DEV=$(ip a | grep ': enp' | tail -1 | cut -d':' -f2 | tr -d '[:space:]')
fi
if [[ -z "$BE_QUIET" ]] ; then
  echo "ETH_DEV=$ETH_DEV"
fi

if [ -z "$SK_USER" ] ; then
  SK_USER='jeff'
fi
if [[ -z "$BE_QUIET" ]] ; then
  echo "SK_USER=$SK_USER"
fi

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

if [[ -z "$BE_QUIET" ]] ; then
  echo "HOST=$HOST"

  echo "Forwarding 127.0.0.1:9000"
  echo "Forwarding 127.0.0.1:9090 (cockpit)"
  echo "Forwarding 127.0.0.1:9100 (invokeai)"
fi

if ! command -v waypipe 2>&1 >/dev/null ; then
  if [[ -z "$BE_QUIET" ]] ; then
    echo "waypipe not found, running SSH directly"
  fi
  exec ssh -X \
    -i /j/ident/azure_sidekick \
    -L 127.0.0.1:9000:127.0.0.1:9000 \
    -L 127.0.0.1:9090:127.0.0.1:9090 \
    -L 127.0.0.1:9100:127.0.0.1:9100 \
    -p $PORT \
     $SK_USER@$HOST "$@"
else
  if [[ -z "$BE_QUIET" ]] ; then
    echo "Forwarding grapics with waypipe"
  fi
  if [ -z "$WAYPIPE" ] ; then
    export WAYPIPE=egl
  fi
  export WAYPIPE=$WAYPIPE
  exec waypipe ssh -X \
    -i /j/ident/azure_sidekick \
    -L 127.0.0.1:9000:127.0.0.1:9000 \
    -L 127.0.0.1:9090:127.0.0.1:9090 \
    -L 127.0.0.1:9100:127.0.0.1:9100 \
    -p $PORT \
     $SK_USER@$HOST "$@"
fi


