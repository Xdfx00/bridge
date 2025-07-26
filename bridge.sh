#!/bin/bash

#
# Author: Aman Shaikh
# Version: 1.1
# Description: Interactive script to configure a Linux bridge on Ubuntu (Netplan)
#              or AlmaLinux (nmcli), with ipcalc check and color-coded output.



source /etc/os-release

# Define color codes
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
NC="\033[0m" # No Color

set -e


# Prompt user for network configuration
echo -e "${BLUE}--- Linux Bridge Configuration ---${NC}"
read -p "Enter the name of the physical interface to bridge (e.g., eth0): " IFACE
read -p "Enter the IP address you wish to assign to the bridge (e.g., 192.168.1.100): " IP
read -p "Enter the netmask (e.g., 255.255.255.0 or /24): " NETMASK
read -p "Enter the gateway (e.g., 192.168.1.1): " GATE

# Check if ipcalc is installed
if ! command -v ipcalc >/dev/null; then
    echo -e "${YELLOW}[INFO] ipcalc not found. Attempting to install...${NC}"
    if grep -qi 'ubuntu' /etc/os-release; then
        apt update -y && apt install -y ipcalc || { echo -e "${RED}[ERROR] Failed to install ipcalc on Ubuntu.${NC}"; exit 1; }
    elif grep -qi 'almalinux' /etc/os-release; then
        dnf update -y && dnf install -y ipcalc || { echo -e "${RED}[ERROR] Failed to install ipcalc on AlmaLinux.${NC}"; exit 1; }
    else
        echo -e "${RED}[ERROR] Unsupported OS. Please install ipcalc manually.${NC}"
        exit 1
    fi
fi


# Convert Netmask to CIDR
CIDR=$(ipcalc ipcalc $IP $NETMASK | awk '/Netmask/ {print $4}')


###########################################
# Ubuntu Bridge Setup using Netplan
###########################################
setup_bridge_ubuntu() {
echo -e "${BLUE}[INFO] Starting Netplan bridge configuration...${NC}"

# considering the server don't have multiples .yamls 
NETPLAN=$(ls /etc/netplan/ | head -n1)

# create backup of .yaml
cp /etc/netplan/$NETPLAN /etc/netplan/$NETPLAN-bak

# Fetecting mac address 
MAC=$(ifconfig $IFACE | grep ether | awk '{print $2}')

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
      interfaces: [ $IFACE ]
      gateway4: $GATE
      macaddress: $MAC
      nameservers:
         addresses:
           - 8.8.8.8
           - 8.8.4.4
EOF
    
    netplan apply
    echo "Bridge configured via Netplan."
}

# Redhat based linux OS setup
setup_bridge_rhel() {

    CIDR_2=$(ipcalc -p $IP $NETMASK | awk -F= {'print $2'})

    nmcli connection add type bridge con-name viifbr0 ifname viifbr0 autoconnect yes
    nmcli connection modify viifbr0 ipv4.addresses $IP/$CIDR_2 ipv4.gateway $GATE ipv4.dns '8.8.8.8'  ipv4.method manual
    nmcli connection modify "$IFACE" master viifbr0
    nmc4li connection modify viifbr0 connection.autoconnect-slaves 1
    nmcli connection up viifbr0
    nmcli connection up "$IFACE"
    echo "Bridge $BRIDGE_NAME configured via nmcli."
}


###########################################
# OS Detection and Setup Trigger
###########################################
if [[ "$ID" == "ubuntu" ]]; then
    echo -e "${BLUE}[INFO] Ubuntu detected.${NC}"
    setup_bridge_ubuntu
elif [[ "$ID" == "almalinux" || "$ID" == "rocky" || "$VARIANT" == "CentOS Stream" ]]; then
    echo -e "${BLUE}[INFO] AlmaLinux detected.${NC}"
    setup_bridge_rhel
else
    echo -e "${RED}[ERROR] Unsupported OS. This script supports only Ubuntu and AlmaLinux.${NC}"
    exit 1
fi