#!/usr/bin/env bash
set -euo pipefail            # стоп на первой ошибке и на пустой переменной

PREFIX=gorelov-09            # у вас — свои значения из варианта

if yc load-balancer network-load-balancer get "$PREFIX-lb" >/dev/null 2>&1; then
  yc load-balancer network-load-balancer delete "$PREFIX-lb"
fi

if yc load-balancer target-group get "$PREFIX-tg" >/dev/null 2>&1; then
  yc load-balancer target-group delete "$PREFIX-tg"
fi

yc compute instance list --format json \
  | jq -r ".[] | select(.name | startswith(\"$PREFIX\")) | .name" \
  | while read -r name; do yc compute instance delete "$name"; done
  
if yc vpc subnet get "$PREFIX-subnet-a" >/dev/null 2>&1; then
  yc vpc subnet update "$PREFIX-subnet-a" --disassociate-route-table >/dev/null 2>&1
fi

if yc vpc route-table get "$PREFIX-rt" >/dev/null 2>&1; then
  yc vpc route-table delete "$PREFIX-rt"
fi

if yc vpc gateway get --name "$PREFIX-nat" >/dev/null 2>&1; then
  yc vpc gateway delete --name "$PREFIX-nat"
fi
  
if yc vpc subnet get "$PREFIX-subnet-a" >/dev/null 2>&1; then
  yc vpc subnet delete "$PREFIX-subnet-a"
fi

if yc vpc subnet get "$PREFIX-subnet-b" >/dev/null 2>&1; then
  yc vpc subnet delete "$PREFIX-subnet-b"
fi

if yc vpc network get "$PREFIX-net" >/dev/null 2>&1; then
  yc vpc network delete "$PREFIX-net"
fi
