#!/bin/bash
#
#********************************************************************
#Author:           YiLing Wu (hj)
#email:            huangjing510@126.com
#Date:             2026-05-14
#FileName:         ssh-keygen-automated.sh
#URL:              https://script.huangjingblog.cn
#Description:      免交互 SSH 密钥生成与分发脚本（生产环境慎用）
#Copyright (C):    2026 All rights reserved
#********************************************************************

# 用法：./ssh-keygen-automated.sh [-P 密码] [-b] [-a]

set -euo pipefail

# ==================== 配置区域 ====================
# SSH 密钥参数
KEY_TYPE="rsa"
KEY_BITS="2048"
KEY_FILE="$HOME/.ssh/id_rsa"

# 设置默认集群节点 IP
NODES=(
    #"10.0.0.202"
    #"10.0.0.203"
    #"10.0.0.204"
    #"10.0.0.205"
    #"10.0.0.206"
    #"10.0.0.207"
    #"10.0.0.208"
)

# 密码：-P 参数传入或运行时交互输入
NODE_PASSWORD=""

# 互相免密模式：-b 参数开启，默认为 false（单向免密）
MUTUAL_MODE=false

# 自动检测模式：-a 参数开启，默认为 false（使用手动配置的 NODES）
AUTO_DETECT=true

# ==================== 颜色与日志 ====================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${NC} $1" >&2; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# show_progress 显示进度条
# @param $1 当前进度（从 1 开始）
# @param $2 总数
# 使用 \r 覆盖当前行实现实时更新
show_progress() {
    local current="$1" total="$2"
    local width=20
    local percent=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    local bar=""
    for ((i = 0; i < filled; i++)); do bar+="█"; done || true
    for ((i = 0; i < empty; i++)); do bar+="░"; done || true
    printf "\r  ${GREEN}[%s]${NC} %3d%% (%d/%d)" "${bar}" "${percent}" "${current}" "${total}" >&2
    if [ "${current}" -eq "${total}" ]; then echo "" >&2; fi
}

# ==================== 前置依赖检查 ====================
# get_os_id 从 /etc/os-release 获取系统 ID
# @return 输出系统 ID（小写），如 debian、ubuntu、centos 等
get_os_id() {
    if [ -f /etc/os-release ]; then
        # shellcheck source=/dev/null
        . /etc/os-release
        echo "${ID}"
    else
        echo ""
    fi
}

# get_pkg_manager 根据系统类型返回包管理器安装命令
# @return 输出包管理器安装命令
get_pkg_manager() {
    local os_id
    os_id=$(get_os_id)

    case "${os_id}" in
        debian|ubuntu|linuxmint|pop)
            echo "apt-get install -y sshpass"
            ;;
        centos|rhel|rocky|alma|ol)
            echo "yum install -y sshpass"
            ;;
        fedora)
            echo "dnf install -y sshpass"
            ;;
        arch|manjaro)
            echo "pacman -S --noconfirm sshpass"
            ;;
        alpine)
            echo "apk add sshpass"
            ;;
        *)
            echo ""
            ;;
    esac
}

# check_deps 检查脚本运行所需的依赖程序
# @return 无返回值，依赖缺失时直接退出
check_deps() {
    if ! command -v sshpass &>/dev/null; then
        local install_cmd
        install_cmd=$(get_pkg_manager)
        if [ -z "${install_cmd}" ]; then
            log_error "sshpass 未安装，且无法检测系统类型，请手动安装"
        else
            log_error "sshpass 未安装，请先执行: ${install_cmd}"
        fi
        exit 1
    fi
}

# ==================== 生成密钥对（免交互） ====================
# generate_key 生成 SSH 密钥对
# 使用 ssh-keygen 免交互生成，支持 RSA 和 Ed25519 算法
# @return 无返回值，生成失败时直接退出
generate_key() {
    log_info "生成 SSH 密钥对..."
    mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"

    if [ -f "${KEY_FILE}" ]; then
        local backup="${KEY_FILE}.bak.$(date +%s)"
        log_warn "密钥已存在，备份至 ${backup}"
        cp "${KEY_FILE}" "${backup}"
        cp "${KEY_FILE}.pub" "${backup}.pub"
    fi

    # -N "" 空密码短语 -q 静默模式 -f 指定密钥路径
    ssh-keygen -t "${KEY_TYPE}" -b "${KEY_BITS}" -N "" -f "${KEY_FILE}" -q
    chmod 600 "${KEY_FILE}" && chmod 644 "${KEY_FILE}.pub"
    log_info "密钥生成成功 → ${KEY_FILE}"
}

# ==================== 分发公钥到所有节点 ====================
# distribute_keys 使用 ssh-copy-id 分发公钥到所有集群节点
# @return 0 全部成功, 1 存在失败节点
distribute_keys() {
    local total=${#NODES[@]} success=0 failed=0
    local failed_nodes=()

    log_info "分发公钥到 ${total} 个节点..."
    local current=0
    for node in "${NODES[@]}"; do
        current=$((current+1))
        # sshpass 免交互 + ssh-copy-id 自动追加公钥
        # 注意：不能加 BatchMode=yes，否则 sshpass 无法传入密码
        if sshpass -p "${NODE_PASSWORD}" \
            ssh-copy-id \
                -o StrictHostKeyChecking=no \
                -o ConnectTimeout=10 \
                -i "${KEY_FILE}.pub" \
                "root@${node}" &>/dev/null; then
            success=$((success + 1))
        else
            failed=$((failed + 1))
            failed_nodes+=("${node}")
        fi
        show_progress "${current}" "${total}"
    done

    if [ ${failed} -gt 0 ]; then
        log_warn "分发完成: ${success} 成功, ${failed} 失败"
        log_warn "失败节点:"
        for n in "${failed_nodes[@]}"; do log_warn "  - ${n}"; done
        return 1
    fi
    log_info "分发完成: ${success}/${total} 全部成功"
    return 0
}

# ==================== 验证免密连接 ====================
# verify_connections 验证所有节点的 SSH 免密连接
# 通过 ssh 命令测试免密登录是否成功
# @return 无返回值，仅输出验证结果
verify_connections() {
    log_info "验证 SSH 免密连接..."
    local total=${#NODES[@]} current=0
    local all_ok=true
    local failed_nodes=()
    for node in "${NODES[@]}"; do
        current=$((current + 1))
        if ! ssh -o ConnectTimeout=5 -o BatchMode=yes \
            "root@${node}" "echo ok" &>/dev/null; then
            all_ok=false
            failed_nodes+=("${node}")
        fi
        show_progress "${current}" "${total}"
    done
    if [ "${all_ok}" = true ]; then
        log_info "所有节点免密验证通过"
    else
        log_error "免密验证失败，以下节点不通:"
        for n in "${failed_nodes[@]}"; do log_error "  - ${n}"; done
    fi
}

# ==================== 自动检测网段节点 ====================
# get_network_info 获取当前机器的网段信息
# @return 输出 格式: IP/掩码位数, 如 192.168.1.100/24
get_network_info() {
    local ip mask_cidr

    # 尝试使用 ip 命令（Linux）
    if command -v ip &>/dev/null; then
        # 获取默认路由的网卡
        local iface
        iface=$(ip route | grep default | head -1 | awk '{print $5}')
        if [ -n "${iface}" ]; then
            ip=$(ip -4 addr show "${iface}" | grep -oP '(?<=inet\s)\d+\.\d+\.\d+\.\d+/\d+' | head -1)
            if [ -n "${ip}" ]; then
                echo "${ip}"
                return 0
            fi
        fi
    fi

    # 回退到 ifconfig（部分系统）
    if command -v ifconfig &>/dev/null; then
        ip=$(ifconfig | grep -oP '(?<=inet\s)\d+\.\d+\.\d+\.\d+' | grep -v '127.0.0.1' | head -1)
        if [ -n "${ip}" ]; then
            # 假设 /24 掩码
            echo "${ip}/24"
            return 0
        fi
    fi

    return 1
}

# cidr_to_range 将 CIDR 格式转换为 IP 范围
# @param $1 CIDR 格式，如 192.168.1.100/24
# @return 输出 起始IP 结束IP
cidr_to_range() {
    local cidr="$1"
    local ip="${cidr%/*}"
    local mask_bits="${cidr#*/}"

    # 计算网络地址和广播地址
    local IFS='.'
    read -r i1 i2 i3 i4 <<< "${ip}"

    # 计算掩码
    local mask=$((0xFFFFFFFF << (32 - mask_bits) & 0xFFFFFFFF))
    local m1=$(( (mask >> 24) & 0xFF ))
    local m2=$(( (mask >> 16) & 0xFF ))
    local m3=$(( (mask >> 8) & 0xFF ))
    local m4=$(( mask & 0xFF ))

    # 网络地址
    local net1=$(( i1 & m1 ))
    local net2=$(( i2 & m2 ))
    local net3=$(( i3 & m3 ))
    local net4=$(( i4 & m4 ))

    # 广播地址
    local bcast1=$(( net1 | (~m1 & 0xFF) ))
    local bcast2=$(( net2 | (~m2 & 0xFF) ))
    local bcast3=$(( net3 | (~m3 & 0xFF) ))
    local bcast4=$(( net4 | (~m4 & 0xFF) ))

    # 起始 IP（网络地址 + 1）
    local start4=$(( net4 + 1 ))
    local start3=${net3}
    local start2=${net2}
    local start1=${net1}
    if [ ${start4} -gt 255 ]; then
        start4=0
        start3=$((start3 + 1))
    fi

    # 结束 IP（广播地址 - 1）
    local end4=$(( bcast4 - 1 ))
    local end3=${bcast3}
    local end2=${bcast2}
    local end1=${bcast1}
    if [ ${end4} -lt 0 ]; then
        end4=254
        end3=$((end3 - 1))
    fi

    echo "${start1}.${start2}.${start3}.${start4} ${end1}.${end2}.${end3}.${end4}"
}

# scan_with_nmap 使用 nmap 扫描网段内的活跃主机
# @param $1 起始 IP
# @param $2 结束 IP
# @return 输出 活跃 IP 列表（每行一个）
scan_with_nmap() {
    local start_ip="$1"
    local end_ip="$2"

    # 提取网段前缀
    local prefix
    prefix=$(echo "${start_ip}" | cut -d'.' -f1-3)

    # 提取起始和结束的最后一位
    local start_last
    start_last=$(echo "${start_ip}" | cut -d'.' -f4)
    local end_last
    end_last=$(echo "${end_ip}" | cut -d'.' -f4)

    # 使用 nmap 扫描
    nmap -sn "${prefix}.${start_last}-${end_last}" 2>/dev/null | \
        grep -oP '\d+\.\d+\.\d+\.\d+' | \
        sort -t. -k4 -n
}

# scan_with_ping 使用 ping 扫描网段内的活跃主机（回退方案）
# @param $1 起始 IP
# @param $2 结束 IP
# @return 输出 活跃 IP 列表（每行一个）
scan_with_ping() {
    local start_ip="$1"
    local end_ip="$2"

    # 提取网段前缀
    local prefix
    prefix=$(echo "${start_ip}" | cut -d'.' -f1-3)

    # 提取起始和结束的最后一位
    local start_last
    start_last=$(echo "${start_ip}" | cut -d'.' -f4)
    local end_last
    end_last=$(echo "${end_ip}" | cut -d'.' -f4)

    # 并发 ping 扫描
    for i in $(seq "${start_last}" "${end_last}"); do
        (
            if ping -c 1 -W 1 "${prefix}.${i}" &>/dev/null; then
                echo "${prefix}.${i}"
            fi
        ) &
    done | sort -t. -k4 -n
}

# get_gateway_ip 获取默认网关 IP
# @return 输出网关 IP，未找到时返回空
get_gateway_ip() {
    if command -v ip &>/dev/null; then
        ip route | grep default | awk '{print $3}' | head -1
    elif command -v route &>/dev/null; then
        route -n | grep '^0.0.0.0' | awk '{print $2}' | head -1
    fi
}

# is_reserved_addr 判断 IP 是否为保留地址（网关/网络/广播地址）
# 排除: .0（网络地址）、.1/.2（网关）、.254/.255（广播/末尾保留）
# @param $1 IP 地址
# @return 0 是保留地址, 1 不是
is_reserved_addr() {
    local ip="$1"
    local last_octet="${ip##*.}"
    [ "${last_octet}" = "0" ] || \
    [ "${last_octet}" = "1" ] || \
    [ "${last_octet}" = "2" ] || \
    [ "${last_octet}" = "254" ] || \
    [ "${last_octet}" = "255" ]
}

# detect_nodes 自动检测网段内的活跃节点
# @return 设置 NODES 数组
detect_nodes() {
    local cidr
    cidr=$(get_network_info)
    if [ -z "${cidr}" ]; then
        log_error "无法获取当前网段信息"
        exit 1
    fi

    local my_ip="${cidr%/*}"
    log_info "当前网段: ${cidr}"
    log_info "本机 IP: ${my_ip}"

    # 获取网关 IP
    local gateway_ip
    gateway_ip=$(get_gateway_ip)
    if [ -n "${gateway_ip}" ]; then
        log_info "网关 IP: ${gateway_ip}"
    fi

    # 计算 IP 范围
    local range
    range=$(cidr_to_range "${cidr}")
    local start_ip end_ip
    read -r start_ip end_ip <<< "${range}"

    log_info "扫描范围: ${start_ip} - ${end_ip}"

    # 扫描活跃主机
    local detected_ips=()
    if command -v nmap &>/dev/null; then
        log_info "使用 nmap 扫描..."
        while IFS= read -r ip; do
            [ -n "${ip}" ] && detected_ips+=("${ip}")
        done < <(scan_with_nmap "${start_ip}" "${end_ip}")
    else
        log_warn "nmap 未安装，使用 ping 扫描（较慢）..."
        local nmap_install_cmd
        case "$(get_os_id)" in
            debian|ubuntu|linuxmint|pop) nmap_install_cmd="apt install -y nmap" ;;
            centos|rhel|rocky|alma|ol|fedora) nmap_install_cmd="yum install -y nmap" ;;
            *) nmap_install_cmd="请手动安装 nmap" ;;
        esac
        log_info "提示: 安装 nmap 可加速扫描 (${nmap_install_cmd})"
        while IFS= read -r ip; do
            [ -n "${ip}" ] && detected_ips+=("${ip}")
        done < <(scan_with_ping "${start_ip}" "${end_ip}")
    fi

    # 过滤掉本机 IP 和保留地址
    NODES=()
    local excluded_count=0
    for ip in "${detected_ips[@]}"; do
        if [ "${ip}" = "${my_ip}" ]; then
            log_info "排除本机: ${ip}"
            excluded_count=$((excluded_count + 1))
        elif [ -n "${gateway_ip}" ] && [ "${ip}" = "${gateway_ip}" ]; then
            log_info "排除网关: ${ip}"
            excluded_count=$((excluded_count + 1))
        elif is_reserved_addr "${ip}"; then
            log_info "排除保留地址: ${ip}（.0/.1/.2/.254/.255）"
            excluded_count=$((excluded_count + 1))
        else
            NODES+=("${ip}")
        fi
    done

    log_info "检测到 ${#detected_ips[@]} 个活跃主机，排除 ${excluded_count} 个，剩余 ${#NODES[@]} 个节点"
    if [ ${#NODES[@]} -eq 0 ]; then
        log_warn "未检测到可用节点"
    fi
}

# ==================== 互相免密相关函数 ====================
# generate_remote_keys 在每个远程节点上生成密钥对
# 使用 sshpass + ssh 在远程节点执行 ssh-keygen 命令
# @return 0 全部成功, 1 存在失败节点
generate_remote_keys() {
    local total=${#NODES[@]} success=0 failed=0
    local failed_nodes=()

    log_info "在远程节点上生成密钥对..."
    local current=0
    for node in "${NODES[@]}"; do
        current=$((current + 1))
        if sshpass -p "${NODE_PASSWORD}" \
            ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
                "root@${node}" \
                "mkdir -p ~/.ssh && chmod 700 ~/.ssh && \
                 rm -f ~/.ssh/id_rsa ~/.ssh/id_rsa.pub && \
                 ssh-keygen -t ${KEY_TYPE} -b ${KEY_BITS} -N '' -f ~/.ssh/id_rsa -q && \
                 chmod 600 ~/.ssh/id_rsa && chmod 644 ~/.ssh/id_rsa.pub" &>/dev/null; then
            success=$((success + 1))
        else
            failed=$((failed + 1))
            failed_nodes+=("${node}")
        fi
        show_progress "${current}" "${total}"
    done

    if [ ${failed} -gt 0 ]; then
        log_warn "密钥生成完成: ${success} 成功, ${failed} 失败"
        log_warn "失败节点:"
        for n in "${failed_nodes[@]}"; do log_warn "  - ${n}"; done
        return 1
    fi
    log_info "密钥生成完成: ${success}/${total} 全部成功"
    return 0
}

# collect_remote_keys 收集所有远程节点的公钥到临时目录
# @return 临时目录路径，失败时返回空字符串
collect_remote_keys() {
    local tmp_dir
    tmp_dir=$(mktemp -d "/tmp/ssh_keys.XXXXXX")
    local total=${#NODES[@]} success=0 failed=0
    local failed_nodes=()

    log_info "收集远程节点公钥..."
    local current=0
    for node in "${NODES[@]}"; do
        current=$((current + 1))
        if sshpass -p "${NODE_PASSWORD}" \
            scp -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
                "root@${node}:~/.ssh/id_rsa.pub" "${tmp_dir}/${node}.pub" &>/dev/null; then
            success=$((success + 1))
        else
            failed=$((failed + 1))
            failed_nodes+=("${node}")
        fi
        show_progress "${current}" "${total}"
    done

    if [ ${failed} -gt 0 ]; then
        log_warn "公钥收集完成: ${success} 成功, ${failed} 失败"
        log_warn "失败节点:"
        for n in "${failed_nodes[@]}"; do log_warn "  - ${n}"; done
    else
        log_info "公钥收集完成: ${success}/${total} 全部成功"
    fi
    echo "${tmp_dir}"
}

# distribute_mutual_keys 将所有公钥分发到所有节点的 authorized_keys
# @param $1 临时目录路径（包含所有节点公钥）
# @return 0 全部成功, 1 存在失败
distribute_mutual_keys() {
    local tmp_dir="$1"
    local pub_files=("${tmp_dir}"/*.pub)
    local total=${#NODES[@]}
    local success=0 failed=0
    local failed_nodes=()

    # 生成合并的 authorized_keys 内容（包含当前机器的公钥）
    local all_keys_file="${tmp_dir}/authorized_keys"
    cp "${KEY_FILE}.pub" "${tmp_dir}/$(hostname).pub"
    cat "${tmp_dir}"/*.pub > "${all_keys_file}"

    log_info "分发公钥到所有节点（互相免密）..."
    local current=0
    for node in "${NODES[@]}"; do
        current=$((current + 1))
        # 将合并的公钥文件传输到远程节点并覆盖 authorized_keys
        if sshpass -p "${NODE_PASSWORD}" \
            scp -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
                "${all_keys_file}" "root@${node}:~/.ssh/authorized_keys" &>/dev/null && \
           sshpass -p "${NODE_PASSWORD}" \
            ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
                "root@${node}" \
                "chmod 600 ~/.ssh/authorized_keys" &>/dev/null; then
            success=$((success + 1))
        else
            failed=$((failed + 1))
            failed_nodes+=("${node}")
        fi
        show_progress "${current}" "${total}"
    done

    # 将合并的公钥也写入当前机器的 authorized_keys（确保远程节点可免密连接当前机器）
    log_info "更新当前机器的 authorized_keys..."
    # 备份现有的 authorized_keys
    if [ -f "$HOME/.ssh/authorized_keys" ]; then
        cp "$HOME/.ssh/authorized_keys" "$HOME/.ssh/authorized_keys.bak.$(date +%s)"
    fi
    # 使用覆盖而非追加，确保公钥列表干净
    cp "${all_keys_file}" "$HOME/.ssh/authorized_keys"
    chmod 600 "$HOME/.ssh/authorized_keys"
    log_info "当前机器 authorized_keys 更新完成"

    if [ ${failed} -gt 0 ]; then
        log_warn "公钥分发完成: ${success} 成功, ${failed} 失败"
        log_warn "失败节点:"
        for n in "${failed_nodes[@]}"; do log_warn "  - ${n}"; done
        return 1
    fi
    log_info "公钥分发完成: ${success}/${total} 全部成功"
    return 0
}

# verify_mutual_connections 验证所有节点间的互相免密连接
# 验证每个节点到其他所有节点的连接
# @return 无返回值，仅输出验证结果
verify_mutual_connections() {
    log_info "验证互相免密连接..."
    local my_ip
    my_ip=$(get_network_info)
    my_ip="${my_ip%/*}"
    local all_nodes=("${my_ip}" "${NODES[@]}")
    local all_ok=true
    local failed_pairs=()

    local node_count=${#all_nodes[@]}
    local total=$((node_count * (node_count - 1)))
    local current=0

    for src in "${all_nodes[@]}"; do
        for dst in "${all_nodes[@]}"; do
            [ "${src}" = "${dst}" ] && continue
            current=$((current+1))

            local ssh_target
            if [ "${src}" = "${my_ip}" ]; then
                ssh_target="root@${dst}"
            else
                ssh_target="root@${src}"
            fi

            if ! sshpass -p "${NODE_PASSWORD}" \
                ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
                    "${ssh_target}" \
                    "ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no root@${dst} echo ok" &>/dev/null; then
                all_ok=false
                failed_pairs+=("${src} → ${dst}")
            fi
            show_progress "${current}" "${total}"
        done
    done

    if [ "${all_ok}" = true ]; then
        log_info "所有节点互相免密验证通过"
    else
        log_error "互相免密验证失败，以下连接不通:"
        for pair in "${failed_pairs[@]}"; do log_error "  - ${pair}"; done
    fi
}

# ==================== 帮助信息 ====================
# show_help 显示脚本帮助信息
# @return 无返回值，输出格式化的帮助文本
show_help() {
    echo -e "${GREEN}SSH 免密密钥自动分发脚本${NC}"
    echo ""
    echo -e "${GREEN}用法${NC}: $0 [选项]"
    echo ""
    echo -e "${GREEN}选项${NC}:"
    echo -e "  ${YELLOW}-p, -P 密码${NC}  指定节点 root 密码（不指定则交互输入）"
    echo -e "  ${YELLOW}-b${NC}          互相免密模式（默认为单向免密）"
    echo -e "  ${YELLOW}-a${NC}          自动检测网段节点（默认使用配置文件中的 NODES）"
    echo -e "  ${YELLOW}-h${NC}          显示此帮助信息"
    echo ""
    echo -e "${GREEN}示例${NC}:"
    echo -e "  # 使用配置文件节点，单向免密"
    echo -e "  $0 -p yourpassword"
    echo ""
    echo -e "  # 使用配置文件节点，互相免密"
    echo -e "  $0 -p yourpassword -b"
    echo ""
    echo -e "  # 自动检测网段节点，互相免密"
    echo -e "  $0 -p yourpassword -a -b"
    echo ""
    echo -e "${GREEN}说明${NC}:"
    echo -e "  - 单向免密: 当前机器 → 所有节点"
    echo -e "  - 互相免密: 所有节点之间互相免密"
    echo -e "  - 自动检测: 扫描当前网段内活跃的主机作为节点"
}

# ==================== 主流程 ====================
# main 脚本主函数，协调各模块执行
# @param $@ 命令行参数
# @return 无返回值，执行失败时直接退出
main() {
    # 解析命令行参数（支持 -p 和 -P）
    while getopts "p:P:bah" opt; do
        case $opt in
            p|P) NODE_PASSWORD="$OPTARG" ;;
            b) MUTUAL_MODE=true ;;
            a) AUTO_DETECT=true ;;
            h) show_help; exit 0 ;;
            *)
                log_error "未知选项: -${OPTARG}"
                echo ""
                show_help
                exit 1
                ;;
        esac
    done

    # 自动检测节点
    if [ "${AUTO_DETECT}" = true ]; then
        detect_nodes
    fi

    # 检查是否有节点
    if [ ${#NODES[@]} -eq 0 ]; then
        log_error "没有可用的节点，请检查 NODES 配置或使用 -a 自动检测"
        exit 1
    fi

    # 未指定密码时交互输入
    if [ -z "${NODE_PASSWORD}" ]; then
        echo -n "请输入节点 root 密码: "
        read -s NODE_PASSWORD
        echo ""
        [ -z "${NODE_PASSWORD}" ] && { log_error "密码不能为空"; exit 1; }
    fi

    echo "============================================" >&2
    echo "   SSH 免密密钥自动分发脚本" >&2
    echo "   节点: ${#NODES[@]} 个" >&2
    echo "   密钥: ${KEY_TYPE}/${KEY_BITS}" >&2
    echo "   模式: $([ "${MUTUAL_MODE}" = true ] && echo '互相免密' || echo '单向免密')" >&2
    echo "   来源: $([ "${AUTO_DETECT}" = true ] && echo '自动检测' || echo '配置文件')" >&2
    echo "============================================" >&2
    echo "" >&2

    # 显示节点列表
    log_info "节点列表:"
    for node in "${NODES[@]}"; do
        echo "  - ${node}" >&2
    done
    echo "" >&2

    check_deps
    generate_key
    echo "" >&2
    distribute_keys
    echo "" >&2

    if [ "${MUTUAL_MODE}" = true ]; then
        # 互相免密模式：在远程节点生成密钥 → 收集公钥 → 分发到所有节点
        generate_remote_keys
        echo "" >&2
        local tmp_dir
        tmp_dir=$(collect_remote_keys)
        echo "" >&2
        distribute_mutual_keys "${tmp_dir}"
        echo "" >&2
        verify_mutual_connections
        # 清理临时目录
        rm -rf "${tmp_dir}"
    else
        # 单向免密模式：仅验证当前机器到节点的连接
        verify_connections
    fi

    echo "" >&2
    log_info "全部执行完毕"
}

main "$@"
