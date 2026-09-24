export PREFIX=gorelov-09

yc compute instance delete "$PREFIX-app-2"
yc compute instance delete "$PREFIX-app-1"
yc vpc subnet delete "$PREFIX-subnet"
yc vpc network delete "$PREFIX-net"

yc vpc network list && yc vpc subnet list && yc compute instance list && yc compute disk list
