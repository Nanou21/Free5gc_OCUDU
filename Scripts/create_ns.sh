#!/bin/bash


# ============================================================
# Free5GC namespace networking
#
# Core/RAN LAN:  enp14s0  (192.168.56.0/24)
# Internet WAN:  wlp15s0
#
# User-plane egress:
#   UE -> ... -> UPF2 -> dn2ns -> host -> wlp15s0 -> Internet
#
# Important:
#   - The host default route is NOT changed.
#   - UPF2 gets the N6 default route.
#   - dn2ns gets the default route toward the host.
#   - The host gets explicit return routes for UE pools.
# ============================================================

CORE_IF="enp14s0"
WAN_IF="wlp15s0"

# =========================
# CREATE NAMESPACES
# =========================
sudo ip netns add upf1ns 2>/dev/null || true
sudo ip netns add upf2ns 2>/dev/null || true
sudo ip netns add dn2ns  2>/dev/null || true

# =========================
# CLEAN STALE INTERFACES
# =========================

# gtp5g interfaces
sudo ip netns exec upf1ns ip link del upfgtp 2>/dev/null || true
sudo ip netns exec upf2ns ip link del upfgtp 2>/dev/null || true

# N6 may have been moved manually between namespaces during testing
sudo ip netns exec upf1ns ip link del upf2-n6 2>/dev/null || true
sudo ip netns exec upf2ns ip link del upf2-n6 2>/dev/null || true
sudo ip netns exec dn2ns  ip link del dn2-veth 2>/dev/null || true

# DN-to-host link
sudo ip link del dn2-host 2>/dev/null || true
sudo ip netns exec dn2ns ip link del dn2-wan 2>/dev/null || true

# Host-side UPF links
sudo ip link del veth-upf1-host 2>/dev/null || true
sudo ip link del veth-upf2-host 2>/dev/null || true
sudo ip link del upf1-data-host 2>/dev/null || true
sudo ip link del upf2-data-host 2>/dev/null || true

# Bring namespace loopbacks up
sudo ip netns exec upf1ns ip link set lo up
sudo ip netns exec upf2ns ip link set lo up
sudo ip netns exec dn2ns  ip link set lo up


# =========================
# UPF1 N4
# =========================
sudo ip link add veth-upf1-host type veth peer name veth-upf1-ns
sudo ip link set veth-upf1-ns netns upf1ns

sudo ip addr add 10.200.1.1/24 dev veth-upf1-host
sudo ip link set veth-upf1-host up

sudo ip netns exec upf1ns ip addr add 10.200.1.2/24 dev veth-upf1-ns
sudo ip netns exec upf1ns ip link set veth-upf1-ns up


# =========================
# UPF2 N4
# =========================
sudo ip link add veth-upf2-host type veth peer name veth-upf2-ns
sudo ip link set veth-upf2-ns netns upf2ns

sudo ip addr add 10.200.2.1/24 dev veth-upf2-host
sudo ip link set veth-upf2-host up

sudo ip netns exec upf2ns ip addr add 10.200.2.2/24 dev veth-upf2-ns
sudo ip netns exec upf2ns ip link set veth-upf2-ns up


# =========================
# UPF1 N3 / DATA
# =========================
sudo ip link add upf1-data-host type veth peer name upf1-data-ns
sudo ip link set upf1-data-ns netns upf1ns

sudo ip addr add 10.201.1.1/30 dev upf1-data-host
sudo ip link set upf1-data-host up

sudo ip netns exec upf1ns ip addr add 10.201.1.2/30 dev upf1-data-ns
sudo ip netns exec upf1ns ip addr add 192.168.56.41/32 dev upf1-data-ns
sudo ip netns exec upf1ns ip link set upf1-data-ns up


# =========================
# UPF2 N3 / DATA
# =========================
sudo ip link add upf2-data-host type veth peer name upf2-data-ns
sudo ip link set upf2-data-ns netns upf2ns

sudo ip addr add 10.201.2.1/30 dev upf2-data-host
sudo ip link set upf2-data-host up

sudo ip netns exec upf2ns ip addr add 10.201.2.2/30 dev upf2-data-ns
sudo ip netns exec upf2ns ip addr add 192.168.56.42/32 dev upf2-data-ns
sudo ip netns exec upf2ns ip link set upf2-data-ns up


# =========================
# UPF2 N6 -> DATA NETWORK
# =========================
sudo ip link add upf2-n6 type veth peer name dn2-veth

sudo ip link set upf2-n6 netns upf2ns
sudo ip link set dn2-veth netns dn2ns

sudo ip netns exec upf2ns ip addr add 10.100.0.254/24 dev upf2-n6
sudo ip netns exec upf2ns ip link set upf2-n6 up

sudo ip netns exec dn2ns ip addr add 10.100.0.1/24 dev dn2-veth
sudo ip netns exec dn2ns ip link set dn2-veth up


# =========================
# DATA NETWORK -> HOST
# =========================
# This is the missing hop that lets dn2ns reach the host's real
# Internet interface (wlp15s0).
sudo ip link add dn2-host type veth peer name dn2-wan
sudo ip link set dn2-wan netns dn2ns

sudo ip addr add 10.101.0.1/30 dev dn2-host
sudo ip link set dn2-host up

sudo ip netns exec dn2ns ip addr add 10.101.0.2/30 dev dn2-wan
sudo ip netns exec dn2ns ip link set dn2-wan up


# =========================
# SMF PFCP ADDRESS
# =========================
sudo ip addr replace 10.200.0.1/32 dev lo


# =========================
# N3 / N4 ROUTES
# =========================

# Host -> UPF N3 addresses
sudo ip route replace 192.168.56.41/32 via 10.201.1.2 dev upf1-data-host
sudo ip route replace 192.168.56.42/32 via 10.201.2.2 dev upf2-data-host

# UPFs -> Core/RAN LAN.
# Explicit src prevents Linux from using 10.201.x.2 as the GTP-U source.
sudo ip netns exec upf1ns \
    ip route replace 192.168.56.0/24 via 10.201.1.1 dev upf1-data-ns src 192.168.56.41

sudo ip netns exec upf2ns \
    ip route replace 192.168.56.0/24 via 10.201.2.1 dev upf2-data-ns src 192.168.56.42

# PFCP / N4 -> SMF
sudo ip netns exec upf1ns \
    ip route replace 10.200.0.1/32 via 10.200.1.1 dev veth-upf1-ns

sudo ip netns exec upf2ns \
    ip route replace 10.200.0.1/32 via 10.200.2.1 dev veth-upf2-ns


# =========================
# N6 DEFAULT / RETURN ROUTES
# =========================

# UPF2 is the PSA / Internet-facing UPF.
# All non-local traffic leaving UPF2 goes to dn2ns.
sudo ip netns exec upf2ns \
    ip route replace default via 10.100.0.1 dev upf2-n6

# dn2ns returns UE traffic to UPF2.
sudo ip netns exec dn2ns \
    ip route replace 10.60.0.0/16 via 10.100.0.254 dev dn2-veth

sudo ip netns exec dn2ns \
    ip route replace 10.61.0.0/16 via 10.100.0.254 dev dn2-veth

# dn2ns sends Internet-bound traffic to the root namespace.
sudo ip netns exec dn2ns \
    ip route replace default via 10.101.0.1 dev dn2-wan

# Root namespace MUST return UE traffic to dn2ns rather than following
# the host default route out wlp15s0.
sudo ip route replace 10.60.0.0/16 via 10.101.0.2 dev dn2-host
sudo ip route replace 10.61.0.0/16 via 10.101.0.2 dev dn2-host

# Useful for host-to-N6 diagnostics.
sudo ip route replace 10.100.0.0/24 via 10.101.0.2 dev dn2-host


# =========================
# IP FORWARDING
# =========================
sudo sysctl -w net.ipv4.ip_forward=1
sudo ip netns exec upf2ns sysctl -w net.ipv4.ip_forward=1
sudo ip netns exec dn2ns  sysctl -w net.ipv4.ip_forward=1


# =========================
# HOST NAT -> WI-FI INTERNET
# =========================
# Do NOT NAT through enp14s0. That interface is the 5G Core/RAN LAN.
# UE Internet traffic is masqueraded only when it exits wlp15s0.

sudo iptables -t nat -C POSTROUTING -s 10.60.0.0/16 -o "$WAN_IF" -j MASQUERADE 2>/dev/null || \
sudo iptables -t nat -A POSTROUTING -s 10.60.0.0/16 -o "$WAN_IF" -j MASQUERADE

sudo iptables -t nat -C POSTROUTING -s 10.61.0.0/16 -o "$WAN_IF" -j MASQUERADE 2>/dev/null || \
sudo iptables -t nat -A POSTROUTING -s 10.61.0.0/16 -o "$WAN_IF" -j MASQUERADE

# Forward UE traffic toward Wi-Fi and allow established replies back.
sudo iptables -C FORWARD -i dn2-host -o "$WAN_IF" -j ACCEPT 2>/dev/null || \
sudo iptables -I FORWARD 1 -i dn2-host -o "$WAN_IF" -j ACCEPT

sudo iptables -C FORWARD -i "$WAN_IF" -o dn2-host \
    -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || \
sudo iptables -I FORWARD 1 -i "$WAN_IF" -o dn2-host \
    -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT


echo
echo "UPF namespace networking configured."
echo "Core/RAN interface : $CORE_IF"
echo "Internet interface : $WAN_IF"
echo "N6 egress          : UPF2 -> dn2ns -> host -> $WAN_IF"
echo
echo "Expected host return routes:"
ip route show 10.60.0.0/16
ip route show 10.61.0.0/16


