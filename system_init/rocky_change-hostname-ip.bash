#!/bin/bash
#
#********************************************************************
#Author:           YiLing Wu (hj)
#email:            huangjing510@126.com
#Date:             2026-07-09
#FileName:         rocky_change-hostname-ip.bash
#URL:              http://huangjingblog.cn:510/
#Description:      Rocky Linux 9 模板机下快速修改主机名和IP地址
#Copyright (C):    2026 All rights reserved
#********************************************************************
#
# Usage: bash rocky_change-hostname-ip.bash <主机名> <IP末段>
# 示例:  bash rocky_change-hostname-ip.bash web01 100
#
# 适配 Rocky Linux 9 NetworkManager（nmconnection 格式）
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
    echo -e "${RED}${BOLD}错误: 参数不足${NC}"
    echo -e "${YELLOW}用法: bash rocky_change-hostname-ip.bash <主机名> <IP末段>${NC}"
    echo -e "${YELLOW}示例: bash rocky_change-hostname-ip.bash web01 100${NC}"
    exit 1
fi

hostname_new="$1"
ip_last_new="$2"

# 校验 IP 末段格式（1-255 的数字）
if ! echo "$ip_last_new" | grep -qE '^[0-9]+$' || [ "$ip_last_new" -lt 1 ] || [ "$ip_last_new" -gt 255 ]; then
    echo -e "${RED}${BOLD}错误: IP末段格式不正确 -> $ip_last_new（应为 1-255 的数字）${NC}"
    exit 1
fi

# ============ 获取当前网络信息 ============
ip_current=$(hostname -I | awk '{print $1}')
ip_prefix=$(echo "$ip_current" | awk -F '.' '{print $1"."$2"."$3"."}')
ip_last_old=$(echo "$ip_current" | awk -F '.' '{print $4}')
ip_new="${ip_prefix}${ip_last_new}"

gateway=$(ip route show default | awk '{print $3}')
if [ -z "$gateway" ]; then
    echo -e "${YELLOW}${BOLD}警告: 未检测到默认网关，将使用 ${ip_prefix}2 作为网关${NC}"
    gateway="${ip_prefix}2"
fi

# ============ 检测网卡配置文件 ============
NM_DIR="/etc/NetworkManager/system-connections"

netcard1=""
for card in ens33 eth0 enp0s3; do
    if [ -f "$NM_DIR/${card}.nmconnection" ]; then
        netcard1="$card"
        break
    fi
done

if [ -z "$netcard1" ]; then
    echo -e "${RED}${BOLD}错误: 未找到 NetworkManager 网卡配置文件${NC}"
    echo -e "${RED}查找目录: $NM_DIR${NC}"
    exit 1
fi

netcard2=""
for card in ens34 eth1 enp0s8; do
    if [ -f "$NM_DIR/${card}.nmconnection" ]; then
        netcard2="$card"
        break
    fi
done

# ============ 显示修改信息 ============
echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}${BOLD}  Rocky Linux 9 模板机初始化工具${NC}"
echo -e "${BLUE}==========================================${NC}"
echo -e "  ${CYAN}当前主机名:${NC} $(hostname)"
echo -e "  ${GREEN}${BOLD}新主机名:${NC}   ${GREEN}$hostname_new${NC}"
echo -e "  ${CYAN}当前 IP:${NC}    $ip_current"
echo -e "  ${GREEN}${BOLD}新 IP:${NC}      ${GREEN}$ip_new${NC}  (前三段 $ip_prefix + 末段 $ip_last_new)"
echo -e "  ${CYAN}网关:${NC}       $gateway"
echo -e "  ${CYAN}网卡1:${NC}      $netcard1"
echo -e "  ${CYAN}网卡2:${NC}      ${netcard2:-${YELLOW}无${NC}}"
echo -e "${BLUE}==========================================${NC}"
echo ""

# ============ [1/5] 关闭防火墙 ============
echo -e "${CYAN}[1/5]${NC} 正在关闭防火墙..."
if systemctl is-active firewalld &>/dev/null; then
    systemctl stop firewalld
    systemctl disable firewalld
    echo -e "      ${GREEN}firewalld 已停止并禁用${NC}"
else
    echo -e "      ${YELLOW}firewalld 未运行，跳过${NC}"
fi

# ============ [2/5] 关闭 SELinux ============
echo ""
echo -e "${CYAN}[2/5]${NC} 正在关闭 SELinux..."
selinux_current=$(getenforce)
if [ "$selinux_current" = "Disabled" ]; then
    echo -e "      ${YELLOW}SELinux 已经关闭，跳过${NC}"
else
    # 临时关闭
    setenforce 0
    echo -e "      ${GREEN}SELinux 已临时关闭 (Permissive)${NC}"
    # 永久关闭
    sed -i 's/^SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
    sed -i 's/^SELINUX=permissive/SELINUX=disabled/' /etc/selinux/config
    echo -e "      ${GREEN}SELinux 已永久关闭（重启后生效）${NC}"
fi

# ============ [3/5] 修改网卡配置文件 ============
echo ""
echo -e "${CYAN}[3/5]${NC} 正在修改网卡配置文件..."

cfg1="$NM_DIR/${netcard1}.nmconnection"
cp "$cfg1" "${cfg1}.bak"
echo -e "      ${YELLOW}已备份: ${cfg1}.bak${NC}"

sed -i "s|^address1=.*|address1=${ip_new}/24,${gateway}|" "$cfg1"

if ! grep -q "^dns=" "$cfg1"; then
    sed -i '/^\[ipv4\]/a dns=223.5.5.5;' "$cfg1"
fi

chmod 600 "$cfg1"
echo -e "      ${GREEN}网卡1 ($netcard1): address1=${ip_new}/24,${gateway}${NC}"

if [ -n "$netcard2" ]; then
    cfg2="$NM_DIR/${netcard2}.nmconnection"
    cp "$cfg2" "${cfg2}.bak"
    sed -i "s|^address1=.*|address1=${ip_new}/24|" "$cfg2"
    chmod 600 "$cfg2"
    echo -e "      ${GREEN}网卡2 ($netcard2): address1=${ip_new}/24${NC}"
fi

# ============ [4/5] 重启网络 ============
echo ""
echo -e "${CYAN}[4/5]${NC} 正在重启网络..."
nmcli con reload
nmcli con down "$netcard1" 2>/dev/null
nmcli con up "$netcard1"

if [ -n "$netcard2" ]; then
    nmcli con down "$netcard2" 2>/dev/null
    nmcli con up "$netcard2"
fi
echo -e "      ${GREEN}网络重启完成${NC}"

# ============ [5/5] 修改主机名 ============
echo ""
echo -e "${CYAN}[5/5]${NC} 正在修改主机名: ${GREEN}${BOLD}$hostname_new${NC}"
hostnamectl set-hostname "$hostname_new"

# ============ 验证结果 ============
echo ""
echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}${BOLD}  初始化完成！请验证以下信息：${NC}"
echo -e "${GREEN}==========================================${NC}"
echo -e "  ${CYAN}主机名:${NC}  ${GREEN}${BOLD}$(hostnamectl --static)${NC}"
echo -e "  ${CYAN}IP 地址:${NC} ${GREEN}${BOLD}$(hostname -I)${NC}"
echo -e "  ${CYAN}网关:${NC}    ${GREEN}$(ip route show default | awk '{print $3}')${NC}"
echo -e "  ${CYAN}防火墙:${NC}  ${RED}$(systemctl is-active firewalld 2>/dev/null || echo 'inactive')${NC}"
echo -e "  ${CYAN}SELinux:${NC} ${RED}$(getenforce)${NC}"
echo -e "${GREEN}==========================================${NC}"
echo ""
echo -e "${YELLOW}提示: 请使用以下命令验证外网连通性:${NC}"
echo -e "  ${BOLD}ping -c 2 223.5.5.5${NC}"
echo -e "  ${BOLD}ping -c 2 www.baidu.com${NC}"
echo ""
