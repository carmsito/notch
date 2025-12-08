#!/bin/bash
asusctl profile -p | grep "Active profile is" | awk '{print $4}'
