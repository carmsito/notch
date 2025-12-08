#!/bin/bash
LC_ALL=C free -m | awk '/Mem:/ {printf "%.1f %.1f", ($3/1024), ($2/1024)}'

