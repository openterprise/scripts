#!/bin/bash

CONNECTIONNAME=YourVPNconnectionName
DNS1IPADDR=X.X.X.X
DNS2IPADDR=Y.Y.Y.Y
SEARCHDOMAIN=exampledomain.com
HOSTNAMETOCHECK=examplehostnametocheck

sudo -u $USERNAME nmcli connection up $CONNECTIONNAME

sudo resolvectl dns ppp0 $DNS1IPADDR $DNS2IPADDR

sudo resolvectl domain ppp0 "$SEARCHDOMAIN"

resolvectl status ppp0

resolvectl query $HOSTNAMETOCHECK

ping $HOSTNAMETOCHECK -c 1
