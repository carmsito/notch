#!/bin/bash
LC_ALL=C
if command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits
elif [ -f /sys/class/drm/card0/device/gpu_busy_percent ]; then
    cat /sys/class/drm/card0/device/gpu_busy_percent
else
    echo 0
fi
