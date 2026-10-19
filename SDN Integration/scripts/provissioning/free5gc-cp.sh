#!/bin/bash

USERNAME='user'
CP_HOST='192.168.0.50'

sudo apt -y update 
sudo apt install -y \
  git wget curl ca-certificates \
  build-essential make gcc g++ \
  cmake pkg-config autoconf libtool \
  libmnl-dev libyaml-dev \
  iproute2 iptables tcpdump

sudo snap install go --classic

# clone repo 
cd "$HOME" || exit

git clone --recursive -b v4.2.3 \
  https://github.com/free5gc/free5gc.git

cd ~/free5gc

git submodule status

# MongoDB installtion
. /etc/os-release
echo "$VERSION_CODENAME"

sudo apt install -y gnupg curl

curl -fsSL \
  https://www.mongodb.org/static/pgp/server-8.0.asc \
  | sudo gpg --dearmor \
      -o /usr/share/keyrings/mongodb-server-8.0.gpg

CODENAME=$(. /etc/os-release; echo "$VERSION_CODENAME")

echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] https://repo.mongodb.org/apt/ubuntu ${CODENAME}/mongodb-org/8.2 multiverse" \
| sudo tee /etc/apt/sources.list.d/mongodb-org-8.2.list

sudo apt update
sudo apt install -y mongodb-org

sudo systemctl enable --now mongod

sudo systemctl status mongod

mongosh --eval 'db.runCommand({ping:1})'

# Compile the control-plane components
cd ~/free5gc

make

ls -lh bin/

# installing webconsole 
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt update
sudo apt install -y nodejs
sudo corepack enable
cd ~/free5gc
make webconsole

# Replace amf config
scp 
