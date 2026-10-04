#!/bin/bash

if rfkill list | grep -q "Soft blocked: yes"; then
    printf '{"text":"󰀝 ","tooltip":"Airplane mode ON"}\n'
else
    printf '{"text":"󰀝 ","tooltip":"Airplane mode OFF"}\n'
fi

