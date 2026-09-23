# 4. Своя сеть и машина командой
export PREFIX=gorelov-09      # подставьте свой префикс
export ZONE=ru-central1-d     # ваша зона из варианта
export CIDR=10.19.1.0/24      # ваша подсеть из варианта
export DISK_SIZE=25           # размер диска из варианта, ГБ

yc vpc network create --name "$PREFIX-net"

yc vpc subnet create \
  --name "$PREFIX-subnet" \
  --network-name "$PREFIX-net" \
  --zone "$ZONE" \
  --range "$CIDR"

yc vpc subnet list


yc compute instance create \
  --name "$PREFIX-web-1" \
  --zone "$ZONE" \
  --platform standard-v3 \
  --cores=2 \
  --core-fraction=20 \
  --memory=2 \
  --preemptible \
  --create-boot-disk image-folder-id=standard-images,image-family=ubuntu-2404-lts,type=network-hdd,size="$DISK_SIZE" \
  --network-interface subnet-name="$PREFIX-subnet",nat-ip-version=ipv4 \
  --ssh-key ~/.ssh/id_ed25519.pub \
  --labels created-by=cli
  
  
  yc compute instance create \
  --name "$PREFIX-web-1" \
  --zone "$ZONE" \
  --platform standard-v3 \
  --cores=2 \
  --core-fraction=20 \
  --memory=2 \
  --preemptible \
  --create-boot-disk image-folder-id=standard-images,image-family=ubuntu-2404-lts,type=network-hdd,size="$DISK_SIZE" \
  --network-interface subnet-name="$PREFIX-subnet",nat-ip-version=ipv4 \
  --ssh-key ~/.ssh/id_ed25519.pub \
  --labels created-by=cli
  
  yc compute instance list
yc compute instance get "$PREFIX-web-1"


yc compute instance get "$PREFIX-web-1" --format json \
  | jq -r '.network_interfaces[0].primary_v4_address.one_to_one_nat.address'


export VM_IP=$(yc compute instance get "$PREFIX-web-1" --format json \  | jq -r '.network_interfaces[0].primary_v4_address.one_to_one_nat.address')
ssh yc-user@"$VM_IP"



#bash
set +H

sudo apt install -y nginx

sudo hostnamectl set-hostname gorelov-09-web-1

sudo sed -i "s|Welcome to nginx!|cloudlab on $(hostname)|g" \
  /var/www/html/index.nginx-debian.html

exit


# 5. Сведения о ресурсах

yc compute instance list

yc compute instance list --format json

yc compute instance list --format json \
  | jq -r '.[] | "\(.name)\t\(.status)\t\(.network_interfaces[0].primary_v4_address.one_to_one_nat.address // "нет")"'
  
# только свои ресурсы
yc compute instance list --format json | jq -r ".[] | select(.name | startswith(\"$PREFIX\")) | .name"

# только имена и статусы остановленных
# полезная говорят тема(верю)
yc compute instance list --format json | jq -r '.[] | select(.status != "RUNNING") | .name'


# 6. Уборка

yc compute instance delete "$PREFIX-web-1"
yc compute instance delete "$PREFIX-web-manual"

yc vpc subnet delete "$PREFIX-subnet"
yc vpc network delete "$PREFIX-net"







# Полезные команды

yc init

export VM_IP=$(yc compute instance get "$PREFIX-web-1" --format json \
  | jq -r '.network_interfaces[0].primary_v4_address.one_to_one_nat.address')
ssh yc-user@"$VM_IP"

set +H #bash

# Показывает базовую информацию: ID, имя, зону, статус и IP-адреса.
yc compute instance list

# Удобно, чтобы быстро глазами найти диски, метаданные или параметры сети.
yc compute instance list --format yaml

# В чистом виде читать тяжело, поэтому всегда используется в связке с 'jq'.
yc compute instance list --format json

# Выводит таблицу подсетей с их зонами (a, b, d) и CIDR-диапазонами (номерами IP).
yc vpc subnet list

# Помогает увидеть, к какому конкретно NETWORK ID привязана каждая подсеть.
yc vpc subnet list --format yaml

# только свои ресурсы
yc compute instance list --format json | jq -r ".[] | select(.name | startswith(\"$PREFIX\")) | .name"

# только имена и статусы остановленных
yc compute instance list --format json | jq -r '.[] | select(.status != "RUNNING") | .name'

# уборка по порядку
yc compute instance delete "$PREFIX-web-1"
yc compute instance delete "$PREFIX-web-manual"

yc vpc subnet delete "$PREFIX-subnet"
yc vpc network delete "$PREFIX-net"



  
  
