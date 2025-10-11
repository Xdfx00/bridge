#!/bin/bash

#
# Author: Aman Shaikh
# Version: 2.0
# Description: Interactive script to configure a Linux bridge on Ubuntu (Netplan)
#              or AlmaLinux (nmcli), with ipcalc check and color-coded output.



source /etc/os-release

# Define color codes
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
NC="\033[0m" # No Color


# Prompt user for network configuration
echo -e "${BLUE}--- Linux Bridge Configuration ---${NC}"

# Detect Ips info directly from server 
IFACE=$(ip route show default | awk '{print $5}')

IP_NET=$(ip -4 addr show $IFACE | grep inet | grep -v '127.0.0.1' | awk '{print $2}')

IP=$(ip -4 addr show $IFACE | grep inet | grep -v '127.0.0.1' | awk '{print $2}' | cut -d'/' -f1)

GW=$(ip route show default | awk '{print $3}')

# Check if ipcalc is installed
if ! command -v ipcalc >/dev/null; then
    echo -e "${YELLOW}[INFO] ipcalc not found. Attempting to install...${NC}"
    if grep -qi 'ubuntu' /etc/os-release; then
        apt-get update -y >/dev/null 2>&1 && apt-get install -y ipcalc >/dev/null 2>&1 || { echo -e "${RED}[ERROR] Failed to install ipcalc on Ubuntu.${NC}"; exit 1; }
    elif [[ "$ID" == "almalinux" || "$ID" == "rocky" || "$ID" == "centos" ]]; then
        dnf install -y ipcalc >/dev/null 2>&1 || { echo -e "${RED}[ERROR] Failed to install ipcalc on AlmaLinux.${NC}"; exit 1; }
    else
        echo -e "${RED}[ERROR] Unsupported OS. Please install ipcalc manually.${NC}"
        exit 1
    fi
fi


# Checking IPv6
IPV6_ADDR=""
IPV6_GW=""

IPV6=$(ip -6 addr show dev $IFACE scope global | grep -w inet6  | awk '{print $2}')
 [[ -n "$IPV6" ]] && IPV6_ADDR=$IPV6


IPV6_GW=$(ip -6 route | awk '/default via/ {print $3; exit}')

# Check if interface exists:
if ! ip link show "$IFACE" >/dev/null 2>&1; then
    echo -e "${RED}[ERROR] Interface $IFACE not found.${NC}"
    exit 1
fi

# Checking if the server provider Hetzner or OVH
DATA=$(curl -sS ipinfo.io/$IP)
if echo "$DATA" | grep -q '"bogon": true'; then
    echo -e "${YELLOW}[INFO] Private IP detected. Skipping ISP detection.${NC}"
    ISP="private"
else
    ISP=$(echo "$DATA" | grep -Eio "hetzner|ovh")
fi

echo -e "${GREEN}[INFO] Detected ISP: ${ISP:-Unknown}.${NC}"


# gathering correct netmask
if [[ $ISP == "Hetzner" ]]
then 
	read -p "Your server is from $ISP so you need to provide the correct nastmask from hetnzer panel.! (eq.. 255.255.255.0)" NETMASK
	CIDR=$(ipcalc $IP $NETMASK | awk '/Netmask/ {print $4}')
fi


# Fetecting mac address
MAC=$(cat /sys/class/net/$IFACE/address)


###########################################
# Ubuntu Bridge Setup using Netplan
###########################################
setup_bridge_ubuntu() {
echo -e "${BLUE}[INFO] Starting Netplan bridge configuration...${NC}"

# considering the server don't have multiples .yamls file
NETPLAN=$(ls /etc/netplan/ | head -n1)

# create backup of .yaml
cp /etc/netplan/$NETPLAN /etc/netplan/$NETPLAN-bak


tee /etc/netplan/$NETPLAN <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $IFACE:
      dhcp4: no
  bridges:
    viifbr0:
      addresses:
        - $IP_NET
        ${IPV6_ADDR:+- $IPV6_ADDR}
      interfaces: [ $IFACE ]
      gateway4: $GW
      ${IPV6_GW:+gateway6: $IPV6_GW}
      macaddress: $MAC
      nameservers:
         addresses:
           - 8.8.8.8
           - 8.8.4.4
EOF

    netplan generate
    netplan apply
    echo -e "${GREEN}[INFO] Applied Default Netplan config.${NC}"
}

# OVH/Hetzner netplan
hetzner_netplan() {

echo -e "${BLUE}[INFO] Starting Netplan bridge configuration...${NC}"

# considering the server don't have multiples .yamls file
NETPLAN=$(ls /etc/netplan/ | head -n1)

# create backup of .yaml
cp /etc/netplan/$NETPLAN /etc/netplan/$NETPLAN-bak

tee /etc/netplan/$NETPLAN <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $IFACE:
      dhcp4: no
  bridges:
    viifbr0:
      addresses:
        - $IP/$CIDR
        ${IPV6_ADDR:+- $IPV6_ADDR}
      interfaces: [ $IFACE ]
      routes:
        - on-link: true
          to: 0.0.0.0/0
          via: $GW
      ${IPV6_GW:+gateway6: $IPV6_GW}
      macaddress: $MAC
      nameservers:
         addresses:
           - 8.8.8.8
           - 8.8.4.4
EOF

    netplan generate
    netplan apply
    echo -e "${GREEN}[INFO] Applied Hetzner Netplan config.${NC}"
}



ovh_netplan() {

echo -e "${BLUE}[INFO] Starting Netplan bridge configuration...${NC}"

# considering the server don't have multiples .yamls file
NETPLAN=$(ls /etc/netplan/ | head -n1)

# create backup of .yaml
cp /etc/netplan/$NETPLAN /etc/netplan/$NETPLAN-bak

tee /etc/netplan/$NETPLAN <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $IFACE:
      dhcp4: no
  bridges:
    viifbr0:
      addresses:
        - $IP_NET
        ${IPV6_ADDR:+- $IPV6_ADDR}
      interfaces: [ $IFACE ]
      routes:
        - on-link: true
          to: 0.0.0.0/0
          via: $GW
      ${IPV6_GW:+gateway6: $IPV6_GW}
      macaddress: $MAC
      nameservers:
         addresses:
           - 8.8.8.8
           - 8.8.4.4
EOF

    netplan generate
    netplan apply
    echo -e "${GREEN}[INFO] Applied OVH/Hetzner Netplan config.${NC}"	
}


# Redhat based linux OS setup
setup_bridge_rhel() {

    CON_NAME=$(nmcli -t -f NAME,DEVICE connection show | grep ":$IFACE" | cut -d: -f1)

    nmcli connection add type bridge con-name viifbr0 ifname viifbr0 autoconnect yes
    nmcli connection modify viifbr0 ipv4.addresses $IP_NET ipv4.gateway $GW ipv4.dns '8.8.8.8'  ipv4.method manual
    if [[ -n "$IPV6_ADDR" ]]; then
    nmcli connection modify viifbr0 ipv6.addresses "$IPV6_ADDR" ipv6.gateway "$IPV6_GW" ipv6.method manual ipv6.dns "2001:4860:4860::8888"
else
    nmcli connection modify viifbr0 ipv6.method ignore
fi
    nmcli connection modify "$CON_NAME" master viifbr0
    nmcli connection modify viifbr0 connection.autoconnect-slaves 1
    nmcli connection up viifbr0
    nmcli connection up "$CON_NAME"

    echo -e "${GREEN}[INFO] Bridge created via nmcli config.${NC}"
}

hetzner_rhel() {

	CON_NAME=$(nmcli -t -f NAME,DEVICE connection show | grep ":$IFACE" | cut -d: -f1)

	nmcli connection add type bridge con-name viifbr0 ifname viifbr0 autoconnect yes
	nmcli connection modify viifbr0 ipv4.addresses $IP/$CIDR ipv4.gateway "$GW" ipv4.dns '8.8.8.8' ipv4.method manual
	if [[ -n "$IPV6_ADDR" ]]; then
	nmcli connection modify viifbr0 ipv6.addresses "$IPV6_ADDR" ipv6.gateway "$IPV6_GW" ipv6.dns "2001:4868::8888" ipv6.method manual
else
	nmcli connection modify viifbr0 ipv6.method ignore
	fi
	nmcli connection modify $CON_NAME master viifbr0
	nmcli connection modify viifbr0 connection.autoconnect-slaves 1
	nmcli connection up viifbr0
	nmcli connection up "$CON_NAME"
}


###########################################
# OS Detection and Setup Trigger
###########################################
if [[ "$ID" == "ubuntu" ]]
then
    echo -e "${BLUE}[INFO] Ubuntu detected.${NC}"
  if [[ "$ISP" == "Hetzner" ]] 
  then
      hetzner_netplan
    elif [[ "$ISP" == OVH ]]
    then
	    ovh_netplan
    else
	    setup_bridge_ubuntu
  fi
elif [[ "$ID" == "almalinux" || "$ID" == "rocky" || "$ID" == "centos" ]]
then
    echo -e "${BLUE}[INFO] RHEL-based distro detected.${NC}"
    if [[ $ISP == "Hetzner" ]]
    then
	    hetzner_rhel
    else
	    setup_bridge_rhel
    fi
else
    echo -e "${RED}[ERROR] Unsupported OS. This script supports only Ubuntu, AlmaLinux, Rockylinux, Centos stream.${NC}"
    exit 1
fi
