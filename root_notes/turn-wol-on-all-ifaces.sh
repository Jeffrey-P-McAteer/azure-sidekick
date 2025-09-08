#!/bin/bash

ip link | awk -F: '$0 !~ "lo|vir|^[^0-9]"{print $2a;getline}' | xargs -I '{}' sudo ethtool -s '{}' wol g
