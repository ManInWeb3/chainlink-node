#!/bin/bash

DOCKER_COMPOSE_VERSION="1.29.2"
MYUSER="ec2-user"
DATA_DISK="/dev/sdb"
DATA_MOUNT_POINT="/data"
DATA_VOLUME_SIZE="400GB"

DISK_FLAG="/sdb"
DATA_VG="data_vg"
DATA_VOLUME="data_volume"

# Update system and install tools
yum update -y
yum install -y mc git jq

# Install docker
amazon-linux-extras install -y docker
systemctl start docker
systemctl enable docker
gpasswd -a $MYUSER docker

# Install docker-compose
curl -L "https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# mount data disk and add it to fstab
#Install & configure LVM to backup data

if [ ! -f "$DISK_FLAG" ]; then
    echo "Initialise LVM on $DATA_DISK disk"
    pvcreate $DATA_DISK
    vgcreate $DATA_VG $DATA_DISK
    lvcreate -L $DATA_VOLUME_SIZE -n $DATA_VOLUME $DATA_VG
    mkfs.ext4 /dev/$DATA_VG/$DATA_VOLUME
    mkdir -p $DATA_MOUNT_POINT
    echo "/dev/$DATA_VG/$DATA_VOLUME $DATA_MOUNT_POINT ext4 noatime,data=writeback,barrier=0,nobh,errors=remount-ro 1 1" >> /etc/fstab
    mount -a
    mkdir -p $DATA_MOUNT_POINT/${blockchain}/
    chmod 777 -R $DATA_MOUNT_POINT
    echo $DATA_DISK > $DISK_FLAG
fi

#Get secrets 

# Get docker compose file

#Generate docker-compose file to run
# export 
env > "$DATA_MOUNT_POINT/env"

cat << EOF > "$DATA_MOUNT_POINT/${docker_compose_filename}"
version: '3.8'
services:
  openethereum-${blockchain}:
    image: openethereum/openethereum:${openethereum_version}
    working_dir: /data
    entrypoint:
      - /home/openethereum/openethereum
      - --mode=active
      - --base-path=/data
      - --chain=${blockchain}
      - --ws-port=8546
      - --ws-interface=all
      - --ws-origins=all
      - --ws-hosts=all
      - --ws-apis=all
      - --jsonrpc-port=8545
      - --jsonrpc-cors=all
      - --jsonrpc-interface=all
      - --jsonrpc-hosts=all
      - --jsonrpc-apis=all
      - --metrics
      - --metrics-port=6060
      - --metrics-interface=all
      - --no-color
      - --warp-barrier=13970800
      - -l sync=trace
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - /etc/timezone:/etc/timezone:ro
      - $DATA_MOUNT_POINT/${blockchain}/:/data/:rw
    ports:
    - "8545:8545"
    - "8546:8546"
    - "30303:30303"
    - "30303:30303/udp"
    restart: unless-stopped
    stop_grace_period: 180s
    networks:
      host_network:

networks:
  host_network:
    driver: bridge
    driver_opts:
      com.docker.network.enable_ipv6: "false"
EOF

docker-compose -f "$DATA_MOUNT_POINT/${docker_compose_filename}" up -d

docker ps
# Run docker-compose services
