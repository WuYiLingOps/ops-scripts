#!/bin/bash
#
#********************************************************************
#Author:           YiLing Wu (hj)
#email:            huangjing510@126.com
#Date:             2026-07-19
#FileName:         install_nginx_apt.bash
#URL:              https://script.huangjingblog.cn
#Description:      Nginx 指定版本一键安装与卸载工具（仅适配Ubuntu/Debian）
#                   - 源策略: 先测试本地 Nexus 源，不可用时自动切换官网源
#                   - 可选择安装指定版本: 1.24/1.26/1.28/1.30
#Copyright (C):    2026 All rights reserved
#********************************************************************

# ==================== 默认配置 ====================
# Nginx 版本选择
#NGINX_VERSION="1.24"  # 可用 2026/07/12
#NGINX_VERSION="1.26"  # 可用 2026/07/12
#NGINX_VERSION="1.28"  # 可用 2026/07/12
NGINX_VERSION="1.30"   # 可用 2026/07/12

# 源自动检测策略（先本地后官网）
# 测试顺序: Nexus 私有源 → nginx 官网源 (https://nginx.org/packages/ubuntu/)
USE_LOCAL_REPO=true           # 启用本地 Nexus 源检测（true/false）

# Nexus 私有源配置
NEXUS_URL="http://nexus.huang.org"

# 颜色定义
GREEN="echo -e \E[32;1m"
RED="echo -e \E[31;1m"
YELLOW="echo -e \E[33;1m"
CYAN="echo -e \E[36;1m"
END="\E[0m"

# 日志函数（自动对齐到第 60 列）
color () {
    RES_COL=60
    MOVE_TO_COL="echo -en \\033[${RES_COL}G"
    SETCOLOR_SUCCESS="echo -en \\033[1;32m"
    SETCOLOR_FAILURE="echo -en \\033[1;31m"
    SETCOLOR_WARNING="echo -en \\033[1;33m"
    SETCOLOR_NORMAL="echo -en \E[0m"
    echo -n "$1" && $MOVE_TO_COL
    echo -n "["
    if [ $2 = "success" -o $2 = "0" ] ;then
        ${SETCOLOR_SUCCESS}
        echo -n $" OK "
    elif [ $2 = "failure" -o $2 = "1" ] ;then
        ${SETCOLOR_FAILURE}
        echo -n $"FAILED"
    else
        ${SETCOLOR_WARNING}
        echo -n $"WARNING"
    fi
    ${SETCOLOR_NORMAL}
    echo -n "]"
    echo
}

# 检查执行结果
check_result() {
    if [ $? -eq 0 ]; then
        color "$1 完成" 0
    else
        color "$1 失败" 1
        exit 1
    fi
}

# 检测系统信息
detect_system() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_ID="${ID}"
        OS_VERSION="${VERSION_ID}"
        OS_NAME="${PRETTY_NAME}"
        OS_CODENAME="${VERSION_CODENAME}"
    else
        color "无法检测系统类型" 1
        exit 1
    fi

    # 检测包管理器
    if command -v apt &> /dev/null; then
        PKG_MANAGER="apt"
    else
        color "当前脚本仅适配Ubuntu/Debian系统（apt），不支持其他包管理器" 1
        exit 1
    fi

    echo -e "系统: ${CYAN}${OS_NAME}${END}"
    echo -e "包管理器: ${CYAN}${PKG_MANAGER}${END}"
}

# 检查root权限
check_root() {
    if [ $EUID -ne 0 ]; then
        color "请使用root用户执行该脚本 (sudo ./install_nginx_apt.bash)" 1
        exit 1
    fi
}

# 测试Nexus源是否可用
test_nexus_repo() {
    local nexus_url="$1"
    local codename="$2"
    local test_url="${nexus_url}/repository/nginx-official-apt/dists/${codename}/Release"

    echo -e "测试 Nexus 源: ${CYAN}${nexus_url}${END}"

    # 测试网络连通性
    if ! curl -fsSL --connect-timeout 5 --max-time 10 "${test_url}" &>/dev/null; then
        color "Nexus 源不可达" 1
        return 1
    fi

    color "Nexus 源可用" 0
    return 0
}

# 配置Nginx源
setup_nginx_repo() {
    echo -e "1. 配置 Nginx 源"

    local codename="${OS_CODENAME:-jammy}"
    local use_nexus=false
    local use_official=false

    # 检查是否已配置且可用
    if [ -f /etc/apt/sources.list.d/nginx-official.list ]; then
        if apt-cache policy nginx 2>/dev/null | grep -q "Candidate:"; then
            color "Nginx 源已配置且可用，跳过配置" 0
            return 0
        fi
        color "Nginx 源存在但不可用，重新配置" 2
    fi

    # 源自动检测策略: 先本地 Nexus → 后官网源 (https://nginx.org/packages/ubuntu/)
    if [ "$USE_LOCAL_REPO" == "true" ]; then
        if test_nexus_repo "${NEXUS_URL}" "${codename}"; then
            use_nexus=true
        fi
    fi

    # 配置源
    if [ "$use_nexus" == "true" ]; then
        # 配置 Nexus 私有源
        color "配置 Nexus 私有源" 0

        # 导入 GPG 密钥
        color "导入 Nginx 签名密钥" 0
        rm -f /usr/share/keyrings/nexus-nginx-official.gpg 2>/dev/null
        curl -fsSL "https://nginx.org/keys/nginx_signing.key" | gpg --dearmor -o /usr/share/keyrings/nexus-nginx-official.gpg

        # 检查 GPG 密钥
        local keyring_option=""
        if [ -f /usr/share/keyrings/nexus-nginx-official.gpg ] && [ -s /usr/share/keyrings/nexus-nginx-official.gpg ]; then
            color "GPG 密钥导入成功" 0
            keyring_option="signed-by=/usr/share/keyrings/nexus-nginx-official.gpg"
        else
            color "GPG 密钥导入失败，使用 trusted=yes 跳过签名验证" 2
            keyring_option="trusted=yes"
        fi

        # 创建源文件
        echo -e "创建 Nginx 源文件 (Nexus)"
        cat > /etc/apt/sources.list.d/nginx-official.list <<EOF
deb [${keyring_option}] ${NEXUS_URL}/repository/nginx-official-apt/ ${codename} nginx
EOF

    elif [ "$USE_LOCAL_REPO" == "true" ]; then
        # 配置官网源（Nexus 不可用时自动切换）
        color "Nexus 源不可用，自动切换到 nginx 官网源" 2
        use_official=true

    else
        # 直接使用官网源（跳过本地源检测）
        color "跳过本地源检测，直接使用 nginx 官网源" 0
        use_official=true
    fi

    # 配置官网源
    if [ "$use_official" == "true" ]; then
        echo -e "配置 nginx 官网源: https://nginx.org/packages/ubuntu/"

        # 导入 GPG 密钥
        color "导入 Nginx 签名密钥" 0
        rm -f /usr/share/keyrings/nginx-official.gpg 2>/dev/null
        curl -fsSL "https://nginx.org/keys/nginx_signing.key" | gpg --dearmor -o /usr/share/keyrings/nginx-official.gpg

        # 检查 GPG 密钥
        local keyring_option=""
        if [ -f /usr/share/keyrings/nginx-official.gpg ] && [ -s /usr/share/keyrings/nginx-official.gpg ]; then
            color "GPG 密钥导入成功" 0
            keyring_option="signed-by=/usr/share/keyrings/nginx-official.gpg"
        else
            color "GPG 密钥导入失败，使用 trusted=yes 跳过签名验证" 2
            keyring_option="trusted=yes"
        fi

        # 创建源文件
        echo -e "创建 Nginx 源文件 (官网)"
        cat > /etc/apt/sources.list.d/nginx-official.list <<EOF
deb [${keyring_option}] https://nginx.org/packages/ubuntu/ ${codename} nginx
deb-src [${keyring_option}] https://nginx.org/packages/ubuntu/ ${codename} nginx
EOF
    fi

    # 更新并验证
    echo -e "更新包列表"
    apt update -qq 2>&1 | tail -5

    if ! apt-cache policy nginx 2>/dev/null | grep -q "Candidate:"; then
        color "Nginx 源配置失败" 1
        exit 1
    fi

    # 显示候选版本
    local candidate_version
    candidate_version=$(apt-cache policy nginx 2>/dev/null | grep "Candidate:" | awk '{print $2}')
    echo -e "Nginx 候选版本: ${CYAN}${candidate_version}${END}"

    color "Nginx 源配置完成" 0
}

# 安装Nginx
install_nginx() {
    echo -e "2. 安装 Nginx ${NGINX_VERSION}"

    # 清理可能残留的破损包状态
    for pkg in nginx-core nginx; do
        if dpkg -l "$pkg" 2>/dev/null | grep -qE "^i[^i]"; then
            echo -e "清除残留的破损状态: ${pkg}"
            dpkg --purge --force-all "$pkg" 2>/dev/null
        fi
    done

    apt update -qq

    # 安装指定版本（源已由 setup_nginx_repo 配置）
    echo -e "安装 Nginx ${NGINX_VERSION}.*"
    apt install -y nginx=${NGINX_VERSION}.*

    check_result "安装 Nginx"

    # 验证安装版本
    local installed_version
    installed_version=$(nginx -v 2>&1 | awk -F'/' '{print $2}')
    echo -e "已安装 Nginx 版本: ${CYAN}${installed_version}${END}"
}

# 启动服务
start_services() {
    echo -e "3. 启动 Nginx 服务"

    systemctl start nginx
    check_result "启动 Nginx"

    systemctl enable nginx
    echo -e "Nginx 开机自启配置完成"
}

# 验证安装
verify_installation() {
    echo -e "4. 验证安装"

    # 检查服务状态
    if systemctl is-active --quiet nginx; then
        echo -e "Nginx 服务运行中"
    else
        color "Nginx 服务未运行" 1
        exit 1
    fi

    # 检查端口监听
    local port
    port=$(ss -tlnp | grep nginx | awk '{print $4}' | cut -d: -f2 | head -1)
    if [ -n "$port" ]; then
        echo -e "Nginx 监听端口: ${CYAN}${port}${END}"
    fi
}

# 安装Nginx
do_install() {
    echo -e "开始安装 Nginx ${NGINX_VERSION}"

    # 检查是否已安装
    if command -v nginx &> /dev/null; then
        local current_version
        current_version=$(nginx -v 2>&1 | awk -F'/' '{print $2}')
        color "检测到 Nginx 已安装，版本: ${current_version}" 2
        read -rp "是否覆盖安装？(Y/n): " confirm
        if [[ "${confirm}" == "n" || "${confirm}" == "N" ]]; then
            color "取消安装" 0
            return 0
        fi
    fi

    # 执行安装步骤
    setup_nginx_repo
    install_nginx
    start_services
    verify_installation

    echo ""
    echo "================================================================"
    color "Nginx 安装完成！" 0
    echo "================================================================"
    echo ""
    echo "  版本信息: $(nginx -v 2>&1)"
    echo "  配置文件: /etc/nginx/nginx.conf"
    echo "  站点目录: /etc/nginx/sites-available/"
    echo "  启用站点: /etc/nginx/sites-enabled/"
    echo ""
}

# 卸载Nginx
do_uninstall() {
    echo -e "开始卸载 Nginx"

    # 检查是否已安装
    if ! command -v nginx &> /dev/null; then
        color "Nginx 未安装，无需卸载" 2
        return 0
    fi

    read -rp "确认卸载 Nginx？(Y/n): " confirm
    if [[ "${confirm}" == "n" || "${confirm}" == "N" ]]; then
        echo -e "取消卸载"
        return 0
    fi

    # 停止服务
    echo -e "停止 Nginx 服务"
    systemctl stop nginx 2>/dev/null
    systemctl disable nginx 2>/dev/null

    # 卸载软件包
    echo -e "卸载 Nginx 软件包"
    apt purge -y nginx nginx-common nginx-core 2>/dev/null
    apt autoremove -y 2>/dev/null

    # 清理残留
    echo -e "清理残留文件"
    rm -rf /etc/nginx /var/log/nginx
    systemctl daemon-reload 2>/dev/null

    # 清理 nginx 源配置
    rm -f /etc/apt/sources.list.d/nginx-official.list 2>/dev/null
    rm -f /usr/share/keyrings/nexus-nginx-official.gpg 2>/dev/null
    rm -f /usr/share/keyrings/nginx-official.gpg 2>/dev/null
    apt update -qq 2>/dev/null

    color "Nginx 卸载完成" 0
}

# 显示帮助
show_help() {
    echo "用法: $0 [选项]"
    echo ""
    echo "说明: 不传参数时默认执行 install"
    echo ""
    echo "选项:"
    echo "  install    安装 Nginx"
    echo "  uninstall  卸载 Nginx"
    echo "  -h,--help  显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  sudo $0          # 默认安装"
    echo "  sudo $0 install"
    echo "  sudo $0 uninstall"
    echo ""
}

# 主函数
main() {
    echo "================================================================"
    echo "          Nginx ${NGINX_VERSION} 安装与卸载工具"
    echo "================================================================"
    echo ""

    # 设置默认操作：不传参时默认为install
    ACTION="${1:-install}"

    case "${ACTION}" in
        install)
            check_root
            detect_system
            do_install
            ;;
        uninstall)
            check_root
            detect_system
            do_uninstall
            ;;
        -h|--help)
            show_help
            ;;
        *)
            color "未知选项: $1" 1
            show_help
            exit 1
            ;;
    esac

    echo ""
    echo "================================================================"
    color "脚本执行完成" 0
    echo "================================================================"
    echo ""
}

main "$@"
