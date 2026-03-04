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
    local monitors_json
    local workspace_id
    local special_id="0"
    local special_name=""
    local special_visible="false"
    local active_state="false"
    local special_state="false"
    local special_ws_state="false"

    monitors_json=$(hyprctl monitors -j 2>/dev/null)
    if [ -z "$monitors_json" ]; then
        echo "false"
        return
    fi

    # Read active workspace + currently displayed special workspace for this monitor.
    workspace_id=$(printf '%s' "$monitors_json" | jq -r --arg m "$MONITOR" '.[] | select(.name == $m) | .activeWorkspace.id')
    special_id=$(printf '%s' "$monitors_json" | jq -r --arg m "$MONITOR" '.[] | select(.name == $m) | (.specialWorkspace.id // 0)')
    special_name=$(printf '%s' "$monitors_json" | jq -r --arg m "$MONITOR" '.[] | select(.name == $m) | (.specialWorkspace.name // "")')
    special_visible=$(printf '%s' "$monitors_json" | jq -r --arg m "$MONITOR" '
        any(
            .[];
            .name == $m
            and ((.specialWorkspace.id // 0) != 0)
            and ((.specialWorkspace.name // "") | startswith("special"))
        )
    ')

    if [ -z "$workspace_id" ] || [ "$workspace_id" = "null" ]; then
        echo "false"
        return
    fi

    # Keep existing behavior: fullscreen on active workspace.
    active_state=$(hyprctl workspaces -j 2>/dev/null | jq -r --argjson wid "$workspace_id" '.[] | select(.id == $wid) | .hasfullscreen // false')

    # Special workspace only affects the bar when it is currently visible on this monitor.
    if [ "$special_visible" = "true" ] && [ -n "$special_name" ]; then
        special_state=$(hyprctl clients -j 2>/dev/null | jq -r --arg s "$special_name" --argjson sid "$special_id" '
            any(
                .[];
                ((.workspace.id == $sid) or (.workspace.name == $s))
                and (
                    ((.fullscreen | tonumber? // 0) > 0)
                    or ((.fullscreenClient | tonumber? // 0) > 0)
                    or (.fullscreen == true)
                    or (.fullscreenClient == true)
                )
            )
        ')

        # Fallback at workspace level for this exact special workspace.
        special_ws_state=$(hyprctl workspaces -j 2>/dev/null | jq -r --arg s "$special_name" --argjson sid "$special_id" '
            any(.[]; ((.id == $sid) or (.name == $s)) and (.hasfullscreen == true))
        ')
    fi

    # echo "$(date) - Event on $MONITOR. Active: $active_state SpecialVisible: $special_visible SpecialId: $special_id SpecialName: $special_name SpecialClients: $special_state SpecialWs: $special_ws_state" >> /tmp/qs_listen_$MONITOR.log
    if [ "$active_state" = "true" ] || [ "$special_state" = "true" ] || [ "$special_ws_state" = "true" ]; then
        echo "true"
    else
        echo "false"
    fi
}

# Initial check
check_full

# Safety net: periodic check in case an IPC event is missed.
while true; do
    check_full
    sleep 1
done &
POLL_PID=$!

# Listen for Hyprland IPC events
socat -U - UNIX-CONNECT:"$SOCKET" | while read -r line; do
    if [[ "$line" == "fullscreen>>"* ]] || [[ "$line" == "workspace>>"* ]] || [[ "$line" == "activewindow>>"* ]] || [[ "$line" == "closewindow>>"* ]] || [[ "$line" == "focusedmon>>"* ]] || [[ "$line" == "openwindow>>"* ]] || [[ "$line" == "movewindow>>"* ]] || [[ "$line" == "activespecial>>"* ]] || [[ "$line" == "activespecialv2>>"* ]]; then
        check_full
    fi
done

kill "$POLL_PID" 2>/dev/null
