#!/usr/bin/env bash
set -euo pipefail            # стоп на первой ошибке и на пустой переменной

# ---- параметры варианта ----
PREFIX=gorelov-09            # префикс имён ресурсов
ZONE_A=ru-central1-d         # зона A
ZONE_B=ru-central1-a         # зона B
CIDR_A=10.19.1.0/24          # подсеть в зоне A
CIDR_B=10.19.2.0/24          # подсеть в зоне B
APP_PORT=8027                # порт, на котором отвечает nginx
GREETING=cloudlab            # слово из варианта, оно же на странице  
BOOT_SIZE=25                 # загрузочный диск, ГБ — из варианта
IMAGE_FAMILY=ubuntu-2404-lts # образ машин, одинаковый у всех вариантов
VM_COUNT=${VM_COUNT:-2}

if [ -n "${1:-}" ]; then
  if [ "$1" = "--web-count" ]; then
    VM_COUNT="$2"
  else
    echo "неизвестный аргумент: $1"
    exit 1
  fi
fi


echo "==> сеть и подсети"
if ! yc vpc network get "$PREFIX-net" >/dev/null 2>&1; then
  yc vpc network create --name "$PREFIX-net"
fi

if ! yc vpc subnet get "$PREFIX-subnet-a" >/dev/null 2>&1; then
  yc vpc subnet create --name "$PREFIX-subnet-a" --network-name "$PREFIX-net" \
    --zone "$ZONE_A" --range "$CIDR_A"
fi

if ! yc vpc subnet get "$PREFIX-subnet-b" >/dev/null 2>&1; then
  yc vpc subnet create --name "$PREFIX-subnet-b" --network-name "$PREFIX-net" \
    --zone "$ZONE_B" --range "$CIDR_B"
fi
  
echo "==> настройка NAT-шлюза"
if ! yc vpc gateway get --name "$PREFIX-nat" >/dev/null 2>&1; then
  yc vpc gateway create --name "$PREFIX-nat"
fi
GW_ID=$(yc vpc gateway get --name "$PREFIX-nat" --format json | jq -r .id)

if ! yc vpc route-table get --name "$PREFIX-rt" >/dev/null 2>&1; then
  yc vpc route-table create --name "$PREFIX-rt" --network-name "$PREFIX-net" \
    --route "destination=0.0.0.0/0,gateway-id=$GW_ID"
fi

yc vpc subnet update --name "$PREFIX-subnet-a" --route-table-name "$PREFIX-rt"

sleep 15  #страховка

echo "==> файл настройки из шаблона"
SSH_KEY=$(cat ~/.ssh/id_ed25519.pub)
export APP_PORT GREETING SSH_KEY
envsubst '${APP_PORT} ${GREETING} ${SSH_KEY}' \
  < hw-01/cloud-init.tpl.yaml > hw-01/cloud-init.yaml
 
  
echo "==> машины"
ZONES=("$ZONE_A" "$ZONE_B")
SUBNETS=("$PREFIX-subnet-a" "$PREFIX-subnet-b")

for i in $(seq 1 "$VM_COUNT"); do
  idx=$(( (i - 1) % 2 ))
  
    VM_NAME="$PREFIX-app-$i"
  if yc compute instance get "$VM_NAME" >/dev/null 2>&1; then
    continue
  fi

  yc compute instance create \
    --name "$VM_NAME" \
    --zone "${ZONES[$idx]}" \
    --platform standard-v3 \
    --cores=2 --core-fraction=20 --memory=2 \
    --preemptible \
    --create-boot-disk image-folder-id=standard-images,image-family="$IMAGE_FAMILY",type=network-hdd,size="$BOOT_SIZE" \
    --network-interface subnet-name="${SUBNETS[$idx]}",nat-ip-version=ipv4 \
    --hostname "$VM_NAME" \
    --metadata-from-file user-data=hw-01/cloud-init.yaml
done

if ! yc compute instance get "$PREFIX-app-server" >/dev/null 2>&1; then
  yc compute instance create \
    --name "$PREFIX-app-server" \
    --zone "$ZONE_A" \
    --platform standard-v3 \
    --cores=2 --core-fraction=20 --memory=2 \
    --preemptible \
    --create-boot-disk image-folder-id=standard-images,image-family="$IMAGE_FAMILY",type=network-hdd,size="$BOOT_SIZE" \
    --network-interface subnet-name="$PREFIX-subnet-a" \
    --hostname "$PREFIX-app-server" \
    --metadata-from-file user-data=hw-01/cloud-init.yaml
fi
  
echo "==> целевая группа"
# собираем список машин: имя подсети и внутренний адрес каждой
TARGETS=""
for i in $(seq 1 "$VM_COUNT"); do
  idx=$(( (i - 1) % 2 ))

  IP=$(yc compute instance get "$PREFIX-app-$i" --format json \
    | jq -r '.network_interfaces[0].primary_v4_address.address')

  TARGETS="$TARGETS --target subnet-name=${SUBNETS[$idx]},address=$IP"
done

if ! yc load-balancer target-group get "$PREFIX-tg" >/dev/null 2>&1; then
  yc load-balancer target-group create --name "$PREFIX-tg" $TARGETS
fi



echo "==> балансировщик"
# идентификатор целевой группы: балансировщик ссылается на неё по нему
TG_ID=$(yc load-balancer target-group get --name "$PREFIX-tg" --format json | jq -r .id)

if ! yc load-balancer network-load-balancer get "$PREFIX-lb" >/dev/null 2>&1; then
  yc load-balancer network-load-balancer create \
    --name "$PREFIX-lb" \
    --region-id ru-central1 \
    --listener name=http,port=80,target-port="$APP_PORT",external-ip-version=ipv4 \
    --target-group target-group-id="$TG_ID",healthcheck-name=http,healthcheck-interval=2s,healthcheck-timeout=1s,healthcheck-unhealthythreshold=2,healthcheck-healthythreshold=2,healthcheck-http-port="$APP_PORT",healthcheck-http-path=/
fi
