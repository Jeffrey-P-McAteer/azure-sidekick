#!/bin/bash

if ! (virsh list | grep -q Builder-Win11) ; then
  virsh start Builder-Win11
fi

cpupower frequency-set -g powersave

virsh setmem Builder-Win11 2048000 --live
virsh setmem Builder-MacOS 2048000 --live

# Every few minutes we update a dynamic DNS record sidekick.jmcateer.com
python /update-dns.py


# Every 24 hours we run 'yay --downloadonly --noconfirm' as the user user
ldt_f='/tmp/.last-download-time'
if ! [[ -e "$ldt_f" ]] ; then
  touch "$ldt_f"
fi
file_time=$(stat --format='%Y' "$ldt_f")
current_time=$(( date +%s ))
if (( file_time < ( current_time - ( 60 * 60 * 24 * 1 ) ) )); then
  echo "$ldt_f is older than 1 days, downloading packages as 'user'!"
  touch "$ldt_f"
  su user yay --downloadonly --noconfirm
fi

# We also manage a physical windows disk which needs to be lit up for 2 hours/day for updates
# Script keeps it's own state and just needs to be invoked periodically
/manage-win-ssd.sh


exit 0

