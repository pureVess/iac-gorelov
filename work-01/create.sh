
export PREFIX=gorelov-09
export ZONE=ru-central1-d
export CIDR=10.19.1.0/24
export DISK_SIZE=25
export IMAGE_FAMILY=debian-12


yc vpc network create --name "$PREFIX-net"

yc vpc subnet create \
  --name "$PREFIX-subnet" \
  --network-name "$PREFIX-net" \
  --zone "$ZONE" \
  --range "$CIDR"

yc compute instance create \
  --name "$PREFIX-app-1" \
  --zone "$ZONE" \
  --platform standard-v3 \
  --cores=2 \
  --core-fraction=20 \
  --memory=2 \
  --preemptible \
  --create-boot-disk image-folder-id=standard-images,image-family="$IMAGE_FAMILY",type=network-hdd,size="$DISK_SIZE" \
  --network-interface subnet-name="$PREFIX-subnet",nat-ip-version=ipv4 \
  --ssh-key ~/.ssh/id_ed25519.pub \
  --labels created-by=cli

yc compute instance create \
  --name "$PREFIX-app-2" \
  --zone "$ZONE" \
  --platform standard-v3 \
  --cores=2 \
  --core-fraction=20 \
  --memory=2 \
  --preemptible \
  --create-boot-disk image-folder-id=standard-images,image-family="$IMAGE_FAMILY",type=network-hdd,size="$DISK_SIZE" \
  --network-interface subnet-name="$PREFIX-subnet",nat-ip-version=ipv4 \
  --ssh-key ~/.ssh/id_ed25519.pub \
  --labels created-by=cli
  
yc vpc network list && yc vpc subnet list && yc compute instance list && yc compute disk list
  
 #Для дальнейшего удобства
 export VM_IP1=$(yc compute instance get "$PREFIX-app-1" --format json \
  | jq -r '.network_interfaces[0].primary_v4_address.one_to_one_nat.address')
  
 export VM_IP2=$(yc compute instance get "$PREFIX-app-2" --format json \
  | jq -r '.network_interfaces[0].primary_v4_address.one_to_one_nat.address')
