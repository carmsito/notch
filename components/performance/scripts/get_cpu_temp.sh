#!/bin/bash
LC_ALL=C
if command -v sensors >/dev/null 2>&1; then
    sensors | awk '/Tctl|Tdie|Package id 0/ {print $2; exit}' | tr -d '+°C'
elif [ -f /sys/class/thermal/thermal_zone0/temp ]; then
    awk '{print $1/1000}' /sys/class/thermal/thermal_zone0/temp
else
    echo 0
fi
