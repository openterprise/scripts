#!/bin/bash

#CentOS 7 part
#gnome-screensaver-command -l ; 

#stats
date -Iseconds
upower -i $(upower -e | grep 'BAT') | grep -E "percentage" | sed 's/\s*\(\w*:\)\s*\(.*\)/\1 \2/'
echo "Entering suspend..."

#sleep 4 ; 
systemctl suspend -i ;

sleep 7 ; 
echo ""
echo "Resume..."
date -Iseconds
upower -i $(upower -e | grep 'BAT') | grep -E "percentage" | sed 's/\s*\(\w*:\)\s*\(.*\)/\1 \2/'
