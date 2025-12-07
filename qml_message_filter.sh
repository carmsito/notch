#!/bin/fish
# Filtre pour supprimer les warnings "Cannot open" de QML
qs 2>&1 | grep -v "Cannot open:" | grep -v "Could not resolve property:"
