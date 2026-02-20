#!/bin/bash
# Dynamically get the Hyprland instance signature
SIGNATURE=$(hyprctl instances -j | jq -r '.[0].instance' 2>/dev/null)
SOCKET="/run/user/$(id -u)/hypr/$SIGNATURE/.socket2.sock"

if [ ! -S "$SOCKET" ]; then
    SOCKET="/tmp/hypr/$SIGNATURE/.socket2.sock"
fi

MONITOR="$1"
# echo "$(date) - Listener started for Monitor: $MONITOR. Socket: $SOCKET" >> /tmp/qs_listen_$MONITOR.log

check_full() {
    # Get the ID of the active workspace on the specified monitor
    local workspace_id=$(hyprctl monitors -j | jq -r --arg m "$MONITOR" '.[] | select(.name == $m) | .activeWorkspace.id')
    
    if [ -z "$workspace_id" ] || [ "$workspace_id" == "null" ]; then
        echo "false"
        return
    fi

    # Check if that workspace has a fullscreen window
    local state=$(hyprctl workspaces -j | jq -r --argjson wid "$workspace_id" '.[] | select(.id == $wid) | .hasfullscreen' 2>/dev/null)
    
    # echo "$(date) - Event detected on $MONITOR. Fullscreen state: $state" >> /tmp/qs_listen_$MONITOR.log
    if [ "$state" = "true" ]; then
        echo "true"
    else
        echo "false"
    fi
}

# Initial check
check_full

# Listen for Hyprland IPC events
socat -U - UNIX-CONNECT:"$SOCKET" | while read -r line; do
    if [[ "$line" == "fullscreen>>"* ]] || [[ "$line" == "workspace>>"* ]] || [[ "$line" == "activewindow>>"* ]] || [[ "$line" == "closewindow>>"* ]] || [[ "$line" == "focusedmon>>"* ]]; then
        check_full
    fi
done
