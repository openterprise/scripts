#!/bin/bash

sudo -u $USERNAME nmcli connection up $CONNECTIONNAME

sudo resolvectl dns ppp0 $DNS1IPADDR $DNS2IPADDR

sudo resolvectl domain ppp0 "$EXAMPLEDOMAIN.COM"

resolvectl status ppp0

resolvectl query EXAMPLEHOSTTOCHECK

ping EXAMPLEHOSTTOCHECK -c 1
