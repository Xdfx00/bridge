# 🛠️ Linux Bridge Configuration Script

**Author:** Aman Shaikh  
**Version:** 2.0  
**License:** MIT  
**Supported OS:** Ubuntu, AlmaLinux, Rocky Linux, CentOS Stream  

---

## 📘 Overview

`bridge.sh` is an **interactive Bash script** that automates the setup of a **Linux network bridge** (`viifbr0`) for servers running on:

- **Ubuntu** (Netplan-based)
- **AlmaLinux / Rocky / CentOS Stream** (nmcli-based)

It automatically detects your network interface, IP configuration, and Internet Service Provider (ISP) — including **Hetzner** and **OVH** — and generates the appropriate bridge configuration.

The script also includes automatic installation of `ipcalc`, IPv6 support, color-coded output for readability, and intelligent configuration depending on your hosting provider.

---

## ⚙️ Features

✅ Auto-detects:
- Network interface, IP, gateway, and MAC address  
- IPv6 configuration (if available)  
- Hosting provider (Hetzner, OVH, or Private IP)  

✅ Automatically:
- Configures Linux bridge using Netplan (Ubuntu) or nmcli (RHEL-based)  
- Installs `ipcalc` if missing  
- Creates a backup of your current Netplan configuration  

✅ Supports:
- Dual-stack (IPv4 + IPv6)  
- Custom CIDR/Netmask entry for Hetzner servers  
- Color-coded, readable output  

---

## 🧩 Prerequisites

- Supported OS:
  - Ubuntu 18+
  - AlmaLinux / Rocky Linux / CentOS Stream 8+

---

## 🚀 Usage

1. **Clone this repository**
   ```bash
   git clone https://github.com/Xdfx00/bridge.git
   cd bridge
   chmox +x bridge.sh
   ./bridge.sh
