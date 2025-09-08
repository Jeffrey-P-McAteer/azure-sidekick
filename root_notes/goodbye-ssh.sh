#!/bin/bash

if [ -n "$SSH_CONNECTION" ]; then
    user=$(whoami)
    wall "🔔 $user has logged out"
fi

