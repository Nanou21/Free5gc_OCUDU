#!/bin/bash

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