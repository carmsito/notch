#!/bin/bash
LC_ALL=C
if command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits
elif [ -f /sys/class/drm/card0/device/hwmon/hwmon0/temp1_input ]; then
    awk '{print $1/1000}' /sys/class/drm/card0/device/hwmon/hwmon0/temp1_input
else
    echo 0
fi
