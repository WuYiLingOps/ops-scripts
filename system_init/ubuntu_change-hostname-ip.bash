#!/bin/bash
#
#********************************************************************
#Author:           YiLing Wu (hj)
#email:            huangjing510@126.com
#Date:             2026-07-10
#FileName:         ubuntu_change-hostname-ip.bash
#URL:              http://huangjingblog.cn:510/
#Description:      Ubuntu 模板机下快速修改主机名和 IP 地址
#Copyright (C):    2026 All rights reserved
#********************************************************************
#
# Usage: bash ubuntu_change-hostname-ip.bash <hostname> <last-octet>
# Example: bash ubuntu_change-hostname-ip.bash web01 100
#
# 适配 Ubuntu Netplan 网络配置
# 第二个参数只需输入 IP 的最后一段数字，脚本会自动拼接前三段

# ============ 颜色定义 ============
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'  # 无颜色

# ============ 参数校验 ============
if [ $# -ne 2 ]; then
    echo -e "${RED}${BOLD}Error: Insufficient parameters${NC}"
    echo -e "${YELLOW}Usage: bash ubuntu_change-hostname-ip.bash <hostname> <last-octet>${NC}"
    echo -e "${YELLOW}Example: bash ubuntu_change-hostname-ip.bash web01 100${NC}"
    exit 1
fi

hostname_new="$1"
ip_last_new="$2"

# 校验 IP 末段格式（1-255 的数字）
if ! echo "$ip_last_new" | grep -qE '^[0-9]+$' || [ "$ip_last_new" -lt 1 ] || [ "$ip_last_new" -gt 255 ]; then
    echo -e "${RED}${BOLD}Error: Invalid last octet -> $ip_last_new (must be a number between 1-255)${NC}"
    exit 1
fi

# ============ 获取当前网络信息 ============
ip_current=$(hostname -I | awk '{print $1}')
ip_prefix=$(echo "$ip_current" | awk -F '.' '{print $1"."$2"."$3"."}')
ip_last_old=$(echo "$ip_current" | awk -F '.' '{print $4}')
ip_new="${ip_prefix}${ip_last_new}"

gateway=$(ip route show default | awk '{print $3}')
if [ -z "$gateway" ]; then
    echo -e "${YELLOW}${BOLD}Warning: No default gateway detected, using ${ip_prefix}2 as gateway${NC}"
    gateway="${ip_prefix}2"
fi

# ============ 检测 Netplan 配置文件 ============
NETPLAN_DIR="/etc/netplan"
netplan_file=""

for cfg in 01-netcfg.yaml 00-installer-config.yaml 50-cloud-init.yaml; do
    if [ -f "$NETPLAN_DIR/$cfg" ]; then
        netplan_file="$cfg"
        break
    fi
done

if [ -z "$netplan_file" ]; then
    echo -e "${RED}${BOLD}Error: Netplan config file not found${NC}"
    echo -e "${RED}Search directory: $NETPLAN_DIR${NC}"
    exit 1
fi

# ============ 显示修改信息 ============
echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}${BOLD}  Ubuntu Template Initialization Tool${NC}"
echo -e "${BLUE}==========================================${NC}"
echo -e "  ${CYAN}Current hostname:${NC} $(hostname)"
echo -e "  ${GREEN}${BOLD}New hostname:${NC}     ${GREEN}$hostname_new${NC}"
echo -e "  ${CYAN}Current IP:${NC}       $ip_current"
echo -e "  ${GREEN}${BOLD}New IP:${NC}           ${GREEN}$ip_new${NC}  (prefix $ip_prefix + last octet $ip_last_new)"
echo -e "  ${CYAN}Gateway:${NC}          $gateway"
echo -e "  ${CYAN}Netplan file:${NC}     $netplan_file"
echo -e "${BLUE}==========================================${NC}"
echo ""

# ============ [1/5] 关闭防火墙 ============
echo -e "${CYAN}[1/5]${NC} Disabling firewall..."
if systemctl is-active ufw &>/dev/null; then
    sudo ufw disable
    echo -e "      ${GREEN}ufw disabled${NC}"
elif systemctl is-active firewalld &>/dev/null; then
    sudo systemctl stop firewalld
    sudo systemctl disable firewalld
    echo -e "      ${GREEN}firewalld stopped and disabled${NC}"
else
    echo -e "      ${YELLOW}No firewall running, skipped${NC}"
fi

# ============ [2/5] 关闭 SELinux ============
echo ""
echo -e "${CYAN}[2/5]${NC} Checking SELinux..."
if command -v getenforce &>/dev/null; then
    selinux_current=$(getenforce)
    if [ "$selinux_current" = "Disabled" ]; then
        echo -e "      ${YELLOW}SELinux already disabled, skipped${NC}"
    else
        sudo setenforce 0
        echo -e "      ${GREEN}SELinux temporarily disabled (Permissive)${NC}"
        sudo sed -i 's/^SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
        sudo sed -i 's/^SELINUX=permissive/SELINUX=disabled/' /etc/selinux/config
        echo -e "      ${GREEN}SELinux permanently disabled (takes effect after reboot)${NC}"
    fi
else
    echo -e "      ${YELLOW}SELinux not installed, skipped${NC}"
fi

# ============ [3/5] 修改 Netplan 配置文件 ============
echo ""
echo -e "${CYAN}[3/5]${NC} Modifying Netplan config file..."

cfg_path="$NETPLAN_DIR/$netplan_file"
sudo cp "$cfg_path" "${cfg_path}.bak"
echo -e "      ${YELLOW}Backup created: ${cfg_path}.bak${NC}"

# 提取当前网卡名称
netcard=$(sudo grep -oP '^\s+\K\w+(?=:)' "$cfg_path" | head -1)
if [ -z "$netcard" ]; then
    netcard="ens33"
fi

# 修改 IP 地址（只替换 addresses 部分的 IP，不影响 routes 的网关）
# 匹配格式：- 10.0.0.xxx/24
sudo sed -i "s/- ${ip_prefix}[0-9]\+\/24/- ${ip_new}\/24/" "$cfg_path"

echo -e "      ${GREEN}NIC ($netcard): IP changed to ${ip_new}/24${NC}"

# ============ [4/5] 重启网络 ============
echo ""
echo -e "${CYAN}[4/5]${NC} Restarting network..."
sudo netplan apply
echo -e "      ${GREEN}Network restarted${NC}"

# ============ [5/5] 修改主机名 ============
echo ""
echo -e "${CYAN}[5/5]${NC} Setting hostname: ${GREEN}${BOLD}$hostname_new${NC}"
sudo hostnamectl set-hostname "$hostname_new"

# ============ 配置命令行显示 ============
echo ""
grep -q "PS1=" /etc/profile 2>/dev/null
if [ $? -ne 0 ]; then
    cat >>/etc/profile <<'EOF'
# 短主机名和仅当前目录名
export PS1='[\[\e[34;1m\]\u\[\e[0m\]@\[\e[32;1m\]\h\[\e[0m\]\[\e[31;1m\] \W\[\e[0m\]]\$ '
# 全主机名和全目录名显示
# export PS1='[\[\e[34;1m\]\u\[\e[0m\]@\[\e[32;1m\]\H\[\e[0m\]\[\e[31;1m\] \w\[\e[0m\]]\$ '
EOF
    echo -e "      ${GREEN}PS1 configured in /etc/profile${NC}"
else
    echo -e "      ${YELLOW}PS1 already configured in /etc/profile, skipped${NC}"
fi

# ============ 验证结果 ============
echo ""
echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}${BOLD}  Initialization complete! Please verify:${NC}"
echo -e "${GREEN}==========================================${NC}"
echo -e "  ${CYAN}Hostname:${NC}  ${GREEN}${BOLD}$(hostnamectl --static)${NC}"
echo -e "  ${CYAN}IP Address:${NC} ${GREEN}${BOLD}$(hostname -I)${NC}"
echo -e "  ${CYAN}Gateway:${NC}   ${GREEN}$(ip route show default | awk '{print $3}')${NC}"
echo -e "  ${CYAN}Firewall:${NC}  ${RED}$(sudo ufw status 2>/dev/null || sudo systemctl is-active firewalld 2>/dev/null || echo 'inactive')${NC}"
