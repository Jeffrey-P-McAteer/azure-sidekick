#!/bin/bash

cat <<EOF
Welcome to Azure-SideKick!

EOF

echo 'Active Users'
who


echo

if [ -n "$SSH_CONNECTION" ]; then
    user=$(whoami)
    host=$(echo $SSH_CONNECTION | awk '{print $1}')
    wall "🔔 $user has logged in from $host"
fi

