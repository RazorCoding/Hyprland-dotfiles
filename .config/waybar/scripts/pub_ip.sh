#!/bin/bash
ip=$(curl -s https://api.ipify.org)
echo -n "$ip"
