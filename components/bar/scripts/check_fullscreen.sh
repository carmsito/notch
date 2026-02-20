#!/bin/bash
if [ "$(hyprctl activeworkspace -j | jq '.hasfullscreen')" = "true" ]; then
    echo "true"
else
    echo "false"
fi
