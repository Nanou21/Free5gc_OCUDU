#!/bin/bash
sudo sysctl -w net.ipv4.ip_forward=1

echo 'net.ipv4.ip_forward = 1' | \
sudo tee /etc/sysctl.d/99-free5gc-upf.conf

echo --------------------------
echo verify 
echo --------------------------
sysctl net.ipv4.ip_forward
echo --------------------------

# NAT for UE2 traffic leaving N6
sudo iptables -t nat -C POSTROUTING \
  -s 10.60.2.0/24 -o ens33 -j MASQUERADE 2>/dev/null || \
sudo iptables -t nat -A POSTROUTING \
  -s 10.60.2.0/24 -o ens33 -j MASQUERADE

# Allow outgoing UE traffic
sudo iptables -C FORWARD \
  -s 10.60.2.0/24 -o ens33 -j ACCEPT 2>/dev/null || \
sudo iptables -I FORWARD 1 \
  -s 10.60.2.0/24 -o ens33 -j ACCEPT

# Allow established return traffic
sudo iptables -C FORWARD \
  -d 10.60.2.0/24 -i ens33 \
  -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || \
sudo iptables -I FORWARD 1 \
  -d 10.60.2.0/24 -i ens33 \
  -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

echo --------------------------
echo verify 
echo --------------------------
sudo iptables -t nat -L POSTROUTING -n -v --line-numbers
sudo iptables -L FORWARD -n -v --line-numbers
echo --------------------------