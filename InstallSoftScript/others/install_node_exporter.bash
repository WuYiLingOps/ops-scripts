#!/bin/bash
#
#********************************************************************
#Author:           YiLing Wu (hj)
#email:            huangjing510@126.com
#Date:             2026-10-22 21:50:49
#FileName:         install_node_exporter.bash
#URL:              https://script.huangjingblog.cn
#Description:      node_exporter 安装与卸载工具，支持 Ubuntu/CentOS/Rocky Linux
#Copyright (C):    2026 All rights reserved
#********************************************************************
#

# ==================== 可修改配置 ====================
# 如需更换版本或端口，直接修改以下变量后重新执行脚本
NODE_EXPORTER_VERSION="1.12.1"
LISTEN_PORT="9100"

# ==================== 固定路径配置 ====================
SRC_DIR="/usr/local/src"
INSTALL_DIR="/usr/local/node_exporter"
RUN_USER="prometheus"
RUN_GROUP="prometheus"
SERVICE_FILE="/lib/systemd/system/node_exporter.service"
# 优先使用 gh-proxy 加速，失败后回退 GitHub 官方源
GITHUB_RELEASE_URL="https://github.com/prometheus/node_exporter/releases/download"
GH_PROXY_PREFIX="https://gh-proxy.com/"

# ==================== 颜色定义 ====================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ==================== 日志函数 ====================
log_info() {
    echo -e "${GREEN}[INFO]${RESET} $1"
}
log_warn() {
    echo -e "${YELLOW}[WARN]${RESET} $1"
}
log_error() {
    echo -e "${RED}[ERROR]${RESET} $1"
}
log_step() {
    echo -e "${BLUE}[STEP]${RESET} ${BOLD}$1${RESET}"
}

# ==================== 检查命令执行结果 ====================
check_result() {
    if [ $? -eq 0 ]; then
        log_info "$1 成功"
    else
        log_error "$1 失败，脚本退出"
        exit 1
    fi
}
# ==================== 检测系统信息 ====================
detect_system() {
    log_step "检测系统信息"

    # 检测 CPU 架构，映射为官方发布包命名
    ARCH=$(uname -m)
    case "${ARCH}" in
        x86_64|amd64)
            ARCH_NAME="amd64"
            ;;
        aarch64|arm64)
            ARCH_NAME="arm64"
            ;;
        i386|i686)
            ARCH_NAME="386"
            ;;
        ppc64le)
            ARCH_NAME="ppc64le"
            ;;
        s390x)
            ARCH_NAME="s390x"
            ;;
        *)
            log_error "不支持的架构: ${ARCH}"
            exit 1
            ;;
    esac

    # 检测系统类型
    if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        OS_ID="${ID}"
        OS_NAME="${PRETTY_NAME}"
    else
        log_error "无法检测系统类型，缺少 /etc/os-release"
        exit 1
    fi

    # 仅支持 Ubuntu / CentOS / Rocky Linux
    case "${OS_ID}" in
        ubuntu|centos|rocky)
            ;;
        *)
            log_error "不支持的操作系统: ${OS_ID}，仅支持 ubuntu/centos/rocky"
            exit 1
            ;;
    esac

    # 检测包管理器，用于补齐依赖命令
    if command -v apt-get &> /dev/null; then
        PKG_MANAGER="apt"
    elif command -v dnf &> /dev/null; then
        PKG_MANAGER="dnf"
    elif command -v yum &> /dev/null; then
        PKG_MANAGER="yum"
    else
        log_error "未检测到支持的包管理器"
        exit 1
    fi

    # node_exporter 依赖 systemd 托管服务
    if ! command -v systemctl &> /dev/null; then
        log_error "未检测到 systemd，无法通过 systemctl 管理服务"
        exit 1
    fi

    # 安装包命名依赖架构信息，卸载流程同样需要
    PKG_NAME="node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH_NAME}"
    PKG_FILE="${PKG_NAME}.tar.gz"
    PKG_PATH="${SRC_DIR}/${PKG_FILE}"

    log_info "系统: ${CYAN}${OS_NAME}${RESET}"
    log_info "架构: ${CYAN}${ARCH_NAME}${RESET}"
    log_info "包管理器: ${CYAN}${PKG_MANAGER}${RESET}"
    log_info "目标版本: ${CYAN}v${NODE_EXPORTER_VERSION}${RESET}"
}

# ==================== 检查是否为root用户 ====================
check_root() {
    if [ "${EUID}" -ne 0 ]; then
        log_error "请使用root用户执行该脚本 (sudo ./install_node_exporter.bash)"
        exit 1
    fi
}

# ==================== 检查依赖命令 ====================
check_dependencies() {
    log_step "检查依赖命令"
    local missing=()

    for cmd in wget tar; do
        if ! command -v "${cmd}" &> /dev/null; then
            missing+=("${cmd}")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        log_warn "缺少命令: ${missing[*]}，尝试自动安装"
        case "${PKG_MANAGER}" in
            apt)
                apt-get update -qq && apt-get install -y -qq "${missing[@]}"
                ;;
            dnf)
                dnf install -y "${missing[@]}"
                ;;
            yum)
                yum install -y "${missing[@]}"
                ;;
        esac
        check_result "安装依赖命令"

        for cmd in "${missing[@]}"; do
            if ! command -v "${cmd}" &> /dev/null; then
                log_error "依赖命令 ${cmd} 安装失败"
                exit 1
            fi
        done
    fi

    log_info "依赖命令检查通过"
}
# ==================== 下载安装包 ====================
download_package() {
    log_step "下载 node_exporter v${NODE_EXPORTER_VERSION}"

    PKG_NAME="node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH_NAME}"
    PKG_FILE="${PKG_NAME}.tar.gz"
    PKG_PATH="${SRC_DIR}/${PKG_FILE}"

    mkdir -p "${SRC_DIR}"
    cd "${SRC_DIR}" || exit 1

    # 本地已存在且完整则跳过下载，损坏则删除重下
    if [ -f "${PKG_FILE}" ]; then
        if tar -tzf "${PKG_FILE}" &> /dev/null; then
            log_info "安装包已存在，跳过下载: ${PKG_PATH}"
            return 0
        fi
        log_warn "本地安装包已损坏，删除后重新下载"
        rm -f "${PKG_FILE}"
    fi

    # GitHub 直连较慢，统一走 gh-proxy 加速
    local release_url="${GITHUB_RELEASE_URL}/v${NODE_EXPORTER_VERSION}/${PKG_FILE}"
    local download_url="${GH_PROXY_PREFIX}${release_url}"

    log_info "下载地址: ${download_url}"

    # wget 自带进度与结果日志；加速源失败时回退官方源重试一次
    if ! wget -O "${PKG_FILE}" "${download_url}"; then
        log_warn "加速源下载失败，回退 GitHub 官方源"
        rm -f "${PKG_FILE}"
        if ! wget -O "${PKG_FILE}" "${release_url}"; then
            rm -f "${PKG_FILE}"
            log_error "安装包下载失败，请检查网络，或手动下载 ${PKG_FILE} 放置到 ${SRC_DIR}/"
            exit 1
        fi
    fi

    log_info "安装包下载完成: ${PKG_PATH}"
}

# ==================== 校验安装包 ====================
verify_package() {
    log_step "校验安装包完整性"

    # 本地校验压缩包结构，不联网，可拦截下载中断的半截包
    if ! tar -tzf "${PKG_PATH}" &> /dev/null; then
        log_error "安装包损坏，无法解压: ${PKG_PATH}，请删除后重新执行脚本"
        exit 1
    fi

    log_info "安装包格式检查通过"
}
# ==================== 创建运行用户 ====================
create_user() {
    log_step "创建运行用户 ${RUN_USER}"

    if id "${RUN_USER}" &> /dev/null; then
        log_info "用户 ${RUN_USER} 已存在，跳过创建"
        return 0
    fi

    if ! command -v useradd &> /dev/null; then
        log_error "未找到 useradd 命令，无法创建运行用户"
        exit 1
    fi

    # CentOS 与 Ubuntu 的 nologin 路径不同，需分别探测
    local nologin_shell="/sbin/nologin"
    if [ ! -x "${nologin_shell}" ]; then
        nologin_shell="/usr/sbin/nologin"
    fi

    # -r 创建系统用户，-s 禁止登录
    useradd -r -s "${nologin_shell}" "${RUN_USER}"
    check_result "创建系统用户 ${RUN_USER}"
}

# ==================== 安装二进制文件 ====================
install_binary() {
    log_step "解压并安装 node_exporter"

    # 覆盖安装时先停止旧服务，避免二进制被占用
    if systemctl is-active --quiet node_exporter 2> /dev/null; then
        systemctl stop node_exporter
        log_info "已停止旧版本服务"
    fi

    cd "${SRC_DIR}" || exit 1

    # 清理历史解压目录，避免重复解压产生文件冲突
    if [ -d "${SRC_DIR}/${PKG_NAME}" ]; then
        rm -rf "${SRC_DIR}/${PKG_NAME}"
        log_info "已清理历史解压目录: ${SRC_DIR}/${PKG_NAME}"
    fi

    tar -xzf "${PKG_FILE}"
    check_result "解压安装包"

    if [ ! -f "${SRC_DIR}/${PKG_NAME}/node_exporter" ]; then
        log_error "解压后未找到 node_exporter 可执行文件"
        exit 1
    fi

    # 已存在同名软链接或目录时先移除，避免 ln 创建嵌套链接
    if [ -L "${INSTALL_DIR}" ]; then
        rm -f "${INSTALL_DIR}"
    elif [ -d "${INSTALL_DIR}" ]; then
        log_warn "${INSTALL_DIR} 已存在且非软链接，将被删除"
        rm -rf "${INSTALL_DIR}"
    fi

    ln -s "${SRC_DIR}/${PKG_NAME}" "${INSTALL_DIR}"
    check_result "创建软链接 ${INSTALL_DIR}"

    # 二进制统一收纳到 bin 目录
    cd "${INSTALL_DIR}" || exit 1
    mkdir -p bin
    mv -f node_exporter bin/
    check_result "整理二进制文件到 bin 目录"

    # 软链接目录需按真实路径授权，否则 chown 只作用于链接本身
    chown -R "${RUN_USER}:${RUN_GROUP}" "$(readlink -f "${INSTALL_DIR}")"
    check_result "设置目录属主 ${RUN_USER}"

    log_info "二进制文件路径: ${INSTALL_DIR}/bin/node_exporter"
}
# ==================== 配置 systemd 服务 ====================
write_service() {
    log_step "配置 systemd 服务"

    cat > "${SERVICE_FILE}" <<EOF
[Unit]
Description=Prometheus Node Exporter
After=network.target

[Service]
Type=simple
#no-collector.uname:禁止收集uname信息，会导致grafana无法显示此主机信息
#ExecStart=${INSTALL_DIR}/bin/node_exporter --no-collector.uname --collector.cgroups
ExecStart=${INSTALL_DIR}/bin/node_exporter --web.listen-address=:${LISTEN_PORT} --collector.cgroups
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
User=${RUN_USER}
Group=${RUN_GROUP}

[Install]
WantedBy=multi-user.target
EOF
    chmod 0644 "${SERVICE_FILE}"
    check_result "写入 systemd 服务文件"

    systemctl daemon-reload
    check_result "重载 systemd 配置"

    log_info "服务文件: ${SERVICE_FILE}"
}

# ==================== 配置防火墙 ====================
config_firewall() {
    log_step "配置防火墙放行 ${LISTEN_PORT} 端口"

    # firewalld（CentOS/Rocky 常见）
    if command -v firewall-cmd &> /dev/null && systemctl is-active --quiet firewalld; then
        firewall-cmd --permanent --add-port="${LISTEN_PORT}/tcp" > /dev/null 2>&1
        firewall-cmd --reload > /dev/null 2>&1
        log_info "firewalld 已放行 ${LISTEN_PORT}/tcp"
        return 0
    fi

    # ufw（Ubuntu 常见）
    if command -v ufw &> /dev/null && ufw status 2> /dev/null | grep -q "Status: active"; then
        ufw allow "${LISTEN_PORT}/tcp" > /dev/null 2>&1
        log_info "ufw 已放行 ${LISTEN_PORT}/tcp"
        return 0
    fi

    log_warn "未检测到启用的 firewalld/ufw，跳过防火墙配置"
}
# ==================== 启动服务 ====================
start_service() {
    log_step "启动 node_exporter 服务"

    systemctl enable node_exporter > /dev/null 2>&1
    check_result "设置开机自启"

    systemctl restart node_exporter
    check_result "启动 node_exporter 服务"

    # 等待服务进入 active 状态，最多 15 秒
    local i
    for i in $(seq 1 15); do
        if systemctl is-active --quiet node_exporter; then
            break
        fi
        sleep 1
    done

    if ! systemctl is-active --quiet node_exporter; then
        log_error "node_exporter 服务启动失败，请执行 journalctl -u node_exporter -n 50 查看日志"
        exit 1
    fi

    log_info "服务已启动并设置开机自启"
}

# ==================== 验证安装 ====================
verify_install() {
    log_step "验证安装"

    # 校验二进制版本
    local version_output
    version_output=$("${INSTALL_DIR}/bin/node_exporter" --version 2>&1 | head -n 1)
    if echo "${version_output}" | grep -q "version ${NODE_EXPORTER_VERSION}"; then
        log_info "版本校验通过: ${version_output}"
    else
        log_warn "版本信息: ${version_output}（期望 ${NODE_EXPORTER_VERSION}）"
    fi

    # 校验指标接口可访问
    local retry
    local metrics_ok=0
    for retry in $(seq 1 10); do
        if wget -q -O /dev/null --timeout=3 "http://127.0.0.1:${LISTEN_PORT}/metrics"; then
            metrics_ok=1
            break
        fi
        sleep 1
    done

    if [ "${metrics_ok}" -ne 1 ]; then
        log_error "指标接口 http://127.0.0.1:${LISTEN_PORT}/metrics 访问失败，请检查服务日志"
        exit 1
    fi
    log_info "指标接口可访问: http://127.0.0.1:${LISTEN_PORT}/metrics"

    # 校验核心指标存在
    if wget -q -O - --timeout=5 "http://127.0.0.1:${LISTEN_PORT}/metrics" | grep -q "^node_cpu_seconds_total"; then
        log_info "核心指标采集正常"
    else
        log_warn "未采集到 node_cpu_seconds_total 指标，请检查采集器配置"
    fi
}
# ==================== 检查已安装状态 ====================
check_installed() {
    if [ -L "${INSTALL_DIR}" ] || [ -f "${SERVICE_FILE}" ]; then
        log_warn "检测到 node_exporter 已安装"
        if [ -x "${INSTALL_DIR}/bin/node_exporter" ]; then
            log_warn "当前版本: $("${INSTALL_DIR}/bin/node_exporter" --version 2>&1 | head -n 1)"
        fi

        local confirm
        read -rp "是否覆盖安装 v${NODE_EXPORTER_VERSION}？(y/n): " confirm
        if [[ "${confirm}" != "y" && "${confirm}" != "Y" ]]; then
            log_info "取消安装"
            exit 0
        fi
    fi

    return 0
}

# ==================== 安装 node_exporter ====================
do_install() {
    log_step "1. 检查安装环境"
    check_installed
    check_dependencies

    log_step "2. 下载并校验安装包"
    download_package
    verify_package

    log_step "3. 创建用户并安装文件"
    create_user
    install_binary

    log_step "4. 生成服务并启动"
    write_service
    config_firewall
    start_service

    log_step "5. 验证安装"
    verify_install

    # 获取本机首个非回环 IPv4 地址，用于生成抓取配置示例
    local local_ip
    local_ip=$(hostname -I 2> /dev/null | awk '{print $1}')
    if [ -z "${local_ip}" ]; then
        local_ip=$(ip route get 1.1.1.1 2> /dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}')
    fi
    local_ip="${local_ip:-<本机IP>}"

    echo ""
    log_info "${CYAN}使用说明:${RESET}"
    echo "  1. 查看服务状态: systemctl status node_exporter"
    echo "  2. 查看服务日志: journalctl -u node_exporter -f"
    echo "  3. 指标访问地址: http://<本机IP>:${LISTEN_PORT}/metrics"
    echo "  4. 安装包保留路径: ${PKG_PATH}（脚本不自动清理）"
    echo ""
    log_info "${CYAN}Prometheus 抓取配置示例:${RESET}"
    echo "  - job_name: 'node_exporter'"
    echo "    static_configs:"
    echo "      - targets: ['${local_ip}:${LISTEN_PORT}']"
}

# ==================== 卸载 node_exporter ====================
do_uninstall() {
    log_step "1. 检查安装状态"

    if [ ! -L "${INSTALL_DIR}" ] && [ ! -f "${SERVICE_FILE}" ]; then
        log_warn "node_exporter 未安装，无需卸载"
        return 0
    fi

    local confirm
    read -rp "确认卸载 node_exporter？(y/n): " confirm
    if [[ "${confirm}" != "y" && "${confirm}" != "Y" ]]; then
        log_info "取消卸载"
        return 0
    fi

    log_step "2. 停止并移除服务"
    if systemctl list-unit-files 2> /dev/null | grep -q "^node_exporter.service"; then
        systemctl stop node_exporter 2> /dev/null
        systemctl disable node_exporter > /dev/null 2>&1
        log_info "已停止并取消开机自启"
    fi

    rm -f "${SERVICE_FILE}"
    check_result "移除 systemd 服务文件"

    systemctl daemon-reload
    check_result "重载 systemd 配置"

    log_step "3. 清理安装文件"
    # 先删除软链接，再按版本清理解压目录
    if [ -L "${INSTALL_DIR}" ]; then
        rm -f "${INSTALL_DIR}"
        log_info "已删除软链接 ${INSTALL_DIR}"
    fi
    if [ -d "${SRC_DIR}/${PKG_NAME}" ]; then
        rm -rf "${SRC_DIR}/${PKG_NAME}"
        log_info "已删除解压目录 ${SRC_DIR}/${PKG_NAME}"
    fi

    # 仅当用户未被其他进程占用时才删除
    if id "${RUN_USER}" &> /dev/null; then
        if ! pgrep -u "${RUN_USER}" &> /dev/null; then
            userdel "${RUN_USER}" 2> /dev/null && log_info "已删除用户 ${RUN_USER}"
        else
            log_warn "用户 ${RUN_USER} 仍被进程占用，保留该用户"
        fi
    fi

    # 回收防火墙规则
    if command -v firewall-cmd &> /dev/null && systemctl is-active --quiet firewalld; then
        firewall-cmd --permanent --remove-port="${LISTEN_PORT}/tcp" > /dev/null 2>&1
        firewall-cmd --reload > /dev/null 2>&1
        log_info "firewalld 已移除 ${LISTEN_PORT}/tcp 规则"
    fi
    if command -v ufw &> /dev/null && ufw status 2> /dev/null | grep -q "${LISTEN_PORT}/tcp"; then
        ufw delete allow "${LISTEN_PORT}/tcp" > /dev/null 2>&1
        log_info "ufw 已移除 ${LISTEN_PORT}/tcp 规则"
    fi

    log_step "4. 验证卸载"
    if [ ! -L "${INSTALL_DIR}" ] && [ ! -f "${SERVICE_FILE}" ]; then
        log_info "node_exporter 卸载成功"
    else
        log_error "node_exporter 卸载失败，请手动检查残留文件"
        exit 1
    fi
}
# ==================== 显示帮助 ====================
show_help() {
    echo -e "${CYAN}用法:${RESET} $0 [选项]"
    echo ""
    echo -e "${CYAN}说明:${RESET} 不传参数时默认执行install"
    echo ""
    echo -e "${CYAN}选项:${RESET}"
    echo "  install    安装 node_exporter v${NODE_EXPORTER_VERSION}"
    echo "  uninstall  卸载 node_exporter"
    echo "  -h,--help  显示此帮助信息"
    echo ""
    echo -e "${CYAN}版本与端口:${RESET}"
    echo "  默认版本 v${NODE_EXPORTER_VERSION}，默认端口 ${LISTEN_PORT}"
    echo "  如需调整，请编辑脚本顶部“可修改配置”区域后重新执行"
    echo ""
    echo -e "${CYAN}示例:${RESET}"
    echo "  sudo $0          # 默认安装"
    echo "  sudo $0 install"
    echo "  sudo $0 uninstall"
}

# ==================== 主函数 ====================
main() {
    echo -e "${CYAN}================================================================${RESET}"
    echo -e "${CYAN}          node_exporter 安装与卸载工具${RESET}"
    echo -e "${CYAN}================================================================${RESET}"
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
            log_error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac

    echo ""
    echo -e "${CYAN}================================================================${RESET}"
    echo -e "${GREEN}脚本执行完成！${RESET}"
    echo -e "${CYAN}================================================================${RESET}"
    echo ""
}

main "$@"
