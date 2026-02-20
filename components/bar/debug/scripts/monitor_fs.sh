#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/../data/hypr_fs_log.txt"

while true; do
  date >> "$LOG_FILE"
  hyprctl activewindow -j >> "$LOG_FILE"
  echo "---" >> "$LOG_FILE"
  sleep 2
done
