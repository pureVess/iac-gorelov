#!/usr/bin/env bash
set -uo pipefail

PREFIX=gorelov-09
APP_PORT=8027
GREETING=cloudlab
EXIT_STATUS=0

if ! yc compute instance get "$PREFIX-app-1" >/dev/null 2>&1 \
  && ! yc compute instance get "$PREFIX-app-server" >/dev/null 2>&1; then

  echo "✗ стенд выключен или удалён"
  exit 1
fi

if ! yc load-balancer network-load-balancer get --name "$PREFIX-lb" >/dev/null 2>&1; then
  echo "✗ балансировщик не найден"
  EXIT_STATUS=1
else
  LB_IP=$(yc load-balancer network-load-balancer get --name "$PREFIX-lb" \
    --format json | jq -r '.listeners[0].address')

  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://$LB_IP")

  if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ балансировщик отвечает: 200"
  else
    echo "✗ балансировщик отвечает: $HTTP_CODE"
    EXIT_STATUS=1
  fi

  RESPONSES=""

  for i in $(seq 1 10); do
    RESP=$(curl -s "http://$LB_IP")
    RESPONSES="$RESPONSES $RESP"
  done

  if echo "$RESPONSES" | grep -q "$PREFIX-app-1" \
    && echo "$RESPONSES" | grep -q "$PREFIX-app-2"; then

    echo "✓ ответы приходят больше чем с одной машины"
  else
    echo "✗ распределения трафика нет, отвечает одна машина"
    EXIT_STATUS=1
  fi
fi

if ! yc compute instance get "$PREFIX-app-1" >/dev/null 2>&1; then
  echo "✗ сервер приложения недоступен с веб-сервера"
  EXIT_STATUS=1

elif ! yc compute instance get "$PREFIX-app-server" >/dev/null 2>&1; then
  echo "✗ сервер приложения недоступен с веб-сервера"
  EXIT_STATUS=1

else
  WEB1_EXT_IP=$(yc compute instance get "$PREFIX-app-1" --format json \
    | jq -r '.network_interfaces[0].primary_v4_address.one_to_one_nat.address')

  APP_SERVER_INT_IP=$(yc compute instance get "$PREFIX-app-server" --format json \
    | jq -r '.network_interfaces[0].primary_v4_address.address')

  RESP=$(ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_ed25519 \
    student@$WEB1_EXT_IP \
    "curl -s http://$APP_SERVER_INT_IP:$APP_PORT")

  if echo "$RESP" | grep -q "$GREETING"; then
    echo "✓ сервер приложения доступен с веб-сервера по внутреннему адресу"
  else
    echo "✗ сервер приложения недоступен с веб-сервера"
    EXIT_STATUS=1
  fi
fi

exit $EXIT_STATUS
