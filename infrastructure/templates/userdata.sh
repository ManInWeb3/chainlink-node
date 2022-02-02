#!/bin/bash

MYUSER="ec2-user"
# UID and GID of the user in the docker image
OE_UID="1000"
OE_GID="1000"
CL_UID="14933"
CL_GID="14933"

INSTANCE_TYPE="$(curl -s http://169.254.169.254/latest/meta-data/instance-type)"
if [[ $INSTANCE_TYPE == "i3."*  ]]; then
  DATA_DISK="/dev/nvme0n1"
elif [[ $INSTANCE_TYPE == "t3."* || $INSTANCE_TYPE == "t2."* ]]; then
  DATA_DISK="/dev/sdb"
else
  echo "Not supported instance type exit"
  exit 1
fi
DATA_MOUNT_POINT="/data"
DATA_VOLUME_SIZE="400GB"

DISK_FLAG="$(echo $DATA_DISK | cut -d '/' -f3)"
DATA_VG="data_vg"
DATA_VOLUME="data_volume"

# Update system and install tools
yum update -y
yum install -y mc git jq tmux htop

# Install docker
amazon-linux-extras install -y docker
systemctl enable docker
systemctl start docker
gpasswd -a $MYUSER docker

# Install docker-compose
COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest|jq -r '.tag_name')
sh -c "curl -L https://github.com/docker/compose/releases/download/$COMPOSE_VERSION/docker-compose-`uname -s`-`uname -m` > /usr/bin/docker-compose"
chmod +x /usr/bin/docker-compose
docker-compose -v

if [ ! -f "$DISK_FLAG" ]; then
    echo "Initialise LVM on $DATA_DISK disk"
    pvcreate $DATA_DISK
    vgcreate $DATA_VG $DATA_DISK
    lvcreate -L $DATA_VOLUME_SIZE -n $DATA_VOLUME $DATA_VG
    mkfs.ext4 /dev/$DATA_VG/$DATA_VOLUME
    mkdir -p $DATA_MOUNT_POINT
    echo "/dev/$DATA_VG/$DATA_VOLUME $DATA_MOUNT_POINT ext4 noatime,data=writeback,barrier=0,nobh,errors=remount-ro 1 1" >> /etc/fstab
    mount -a
    if mountpoint -q $DATA_MOUNT_POINT; then
      echo "$DATA_MOUNT_POINT already mounted"
    else
      echo "$DATA_MOUNT_POINT not mounted !!!!\n exiting..."
      exit 1
    fi

    mkdir -p $DATA_MOUNT_POINT/${node_to_run}
    echo $DATA_DISK > $DISK_FLAG
fi

function installS5() {
    echo "Installing s5cmd"
    curl -sL -o ./s5cmd.tar.gz https://github.com/peak/s5cmd/releases/download/v1.4.0/s5cmd_1.4.0_Linux-64bit.tar.gz || EXIT_CODE=$?
    tar -xzvf ./s5cmd.tar.gz || EXIT_CODE=$?
    rm -f s5cmd.tar.gz README.md CHANGELOG.md LICENSE || EXIT_CODE=$?
    mv s5cmd /usr/bin || EXIT_CODE=$?
}
installS5

function generateCERTIFICATES() {
  TLS="$1"
  mkdir -p $TLS
  openssl req -x509 -out $TLS/server.crt \
      -keyout $TLS/server.key \
      -newkey rsa:2048 -nodes -sha256 -days 365 \
      -subj '/CN=datachain.co.nz' -extensions EXT -config <( \
      printf "[dn]\nCN=datachain.co.nz\n[req]\ndistinguished_name = dn\n[EXT]\nsubjectAltName=DNS:datachain.co.nz\nkeyUsage=digitalSignature\nextendedKeyUsage=serverAuth")
}

function downloadSECRET() {
  # SecretName="$1"
  # FileName="$2"
  export AWS_DEFAULT_REGION="${aws_region}"
  echo "Saving $1 value into $2"
  aws secretsmanager get-secret-value --secret-id $1 | \
    jq -r '.SecretString' > $2
}

# Creating backup script
cat << EOF > "$DATA_MOUNT_POINT/download_data.sh"
#!/bin/bash
#Copy latest backup
if [ ! -f "$DATA_MOUNT_POINT/${node_to_run}/src_backup.txt" ]; then
  if [[ "${node_to_run}" == "oe" ]]; then
    aws s3 cp s3://${backup_s3}/${node_to_run}/${ethereum_network}/latest_backup.txt $DATA_MOUNT_POINT/${node_to_run}/src_backup.txt
    LATESTBACKUP="\$(cat $DATA_MOUNT_POINT/${node_to_run}/src_backup.txt)"
    time s5cmd --stat cp -c 1000 s3://${backup_s3}/${node_to_run}/${ethereum_network}/\$LATESTBACKUP/* $DATA_MOUNT_POINT/${node_to_run}
    chown -R $OE_UID:$OE_GID $DATA_MOUNT_POINT/oe
  elif [[ "${node_to_run}" == "cl" ]]; then
    chown -R $CL_UID:$CL_GID $DATA_MOUNT_POINT/cl
  else
    echo "WRONG node_to_run!!! exiting ..."
    exit 1
  fi
fi
EOF

# Creating backup script
cat << EOF > "$DATA_MOUNT_POINT/backup.sh"
#!/bin/bash
set -ex
BACKUP_VOL="backup"
BACKUP_DIR="/backup"
# LVM snapshot
sudo lvcreate -n \$BACKUP_VOL -s /dev/$DATA_VG/$DATA_VOLUME -L 40G
sudo mkdir \$BACKUP_DIR
sudo mount /dev/$DATA_VG/\$BACKUP_VOL \$BACKUP_DIR

S3DESTINATION="s3://${backup_s3}/${node_to_run}/${ethereum_network}"
BACKUPDATE="\$(date +%Y%m%d%H%M%S)"

# rm -rf \$BACKUP_DIR/${node_to_run}/keys
s5cmd --stat cp --exclude "lost+found" --exclude "keys" \
      \$BACKUP_DIR/${node_to_run}/ \$S3DESTINATION/\$BACKUPDATE/

printf \$BACKUPDATE > latest_backup.txt
aws s3 mv ./latest_backup.txt \$S3DESTINATION/

sudo umount \$BACKUP_DIR
sudo rm -rf \$BACKUP_DIR
sudo lvremove -f /dev/$DATA_VG/\$BACKUP_VOL
EOF

if [[ "${node_to_run}" == "oe" ]]; then
#Ethereum configs
# 1/3 of Mem
CACHESIZE="$(echo "0.3*$(free -m|grep "Mem:"|awk '{print $2}')"|bc|cut -d'.' -f1)"

#Generate docker-compose files
cat << EOF > "$DATA_MOUNT_POINT/dc-oe-${ethereum_network}.yaml"
version: '3.8'
services:
  oe-${ethereum_network}:
    image: openethereum/openethereum:${openethereum_version}
    working_dir: /data
    entrypoint:
      - /home/openethereum/openethereum
      - --mode=active
      - --base-path=/data
      - --chain=${ethereum_network}
      - --cache-size=$CACHESIZE
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
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - /etc/timezone:/etc/timezone:ro
      - $DATA_MOUNT_POINT/oe/:/data/:rw
    ports:
    - "8545:8545"
    - "8546:8546"
    - "6060:6060"
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

elif [[ "${node_to_run}" == "cl" ]]; then
#Chainlink configs
cat << EOF > "$DATA_MOUNT_POINT/cl-rinkeby.env"
ROOT=/chainlink
LOG_LEVEL=debug
ETH_CHAIN_ID=4
MIN_OUTGOING_CONFIRMATIONS=2
LINK_CONTRACT_ADDRESS=0x01BE23585060835E02B77ef475b0Cc51aA1e0709
GAS_UPDATER_ENABLED=true
ALLOW_ORIGINS=*
TLS_CERT_PATH=/chainlink/tls/server.crt
TLS_KEY_PATH=/chainlink/tls/server.key
EOF
cat << EOF > "$DATA_MOUNT_POINT/cl-kovan.env"
ROOT=/chainlink
LOG_LEVEL=debug
ETH_CHAIN_ID=42
MIN_OUTGOING_CONFIRMATIONS=2
LINK_CONTRACT_ADDRESS=0xa36085F69e2889c224210F603D836748e7dC0088
GAS_UPDATER_ENABLED=true
ALLOW_ORIGINS=*
TLS_CERT_PATH=/chainlink/tls/server.crt
TLS_KEY_PATH=/chainlink/tls/server.key
EOF
cat << EOF > "$DATA_MOUNT_POINT/cl-ethereum.env"
ROOT=/chainlink
LOG_LEVEL=debug
ETH_CHAIN_ID=1
GAS_UPDATER_ENABLED=true
ALLOW_ORIGINS=*
TLS_CERT_PATH=/chainlink/tls/server.crt
TLS_KEY_PATH=/chainlink/tls/server.key
EOF

cat << EOF > "$DATA_MOUNT_POINT/dc-cl-${ethereum_network}.yaml"
version: '3.8'
services:
  cl-${ethereum_network}:
    image: smartcontract/chainlink:${chainlink_version}
    working_dir: /data
    env_file:
      - $DATA_MOUNT_POINT/cl-${ethereum_network}.env
    environment:
      - ETH_URL=${ethereum_url}
      - DATABASE_URL=postgresql://${db_username}:${db_password}@${db_address}:5432/${db_name}
      - DATABASE_TIMEOUT=0
    command: "local n -p /chainlink/.password -a /chainlink/.api"
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - /etc/timezone:/etc/timezone:ro
      - $DATA_MOUNT_POINT/cl/:/chainlink/:rw
    ports:
    - "6689:6689"
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

######========  Generate TLS on CHAINLINK
  generateCERTIFICATES "$DATA_MOUNT_POINT/cl/tls"
  downloadSECRET cl-rinkeby-api "$DATA_MOUNT_POINT/cl/.api"
  downloadSECRET cl-rinkeby-password "$DATA_MOUNT_POINT/cl/.password"
fi

######========  executing scripts  =======################
# Download the data
/bin/bash $DATA_MOUNT_POINT/download_data.sh 2>&1 >> $DATA_MOUNT_POINT/download_data.log

# Run ${node_to_run} container

docker-compose -f "$DATA_MOUNT_POINT/dc-${node_to_run}-${ethereum_network}.yaml" up -d 2>&1 >> $DATA_MOUNT_POINT/dc-up.log

echo "${node_to_run} - is launched."