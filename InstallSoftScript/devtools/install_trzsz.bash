#!/bin/bash
#
#********************************************************************
#Author:           YiLing Wu (hj)
#email:            huangjing510@126.com
#Date:             2026-06-28 15:50:00
#FileName:         install_trzsz.bash
#URL:              https://script.huangjingblog.cn
#Description:      trzsz安装与卸载工具，支持deb/rpm包管理，自动检测系统架构
#Copyright (C):    2026 All rights reserved
#********************************************************************

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

    # 检测架构
    ARCH=$(uname -m)
    case "${ARCH}" in
        x86_64)
            ARCH_NAME="x86_64"
            ;;
        aarch64|arm64)
            ARCH_NAME="aarch64"
            ;;
        armv7l|armhf)
            ARCH_NAME="armhf"
            ;;
        *)
            log_error "不支持的架构: ${ARCH}"
            exit 1
            ;;
    esac

    # 检测系统类型
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_ID="${ID}"
        OS_NAME="${PRETTY_NAME}"
    else
        log_error "无法检测系统类型，缺少 /etc/os-release 文件"
        exit 1
    fi

    # 检测包管理器
    if command -v apt &> /dev/null; then
        PKG_MANAGER="apt"
        PKG_SUFFIX="deb"
    elif command -v yum &> /dev/null; then
        PKG_MANAGER="yum"
        PKG_SUFFIX="rpm"
    elif command -v dnf &> /dev/null; then
        PKG_MANAGER="dnf"
        PKG_SUFFIX="rpm"
    else
        log_error "未检测到支持的包管理器 (apt/yum/dnf)"
        exit 1
    fi

    log_info "系统: ${CYAN}${OS_NAME}${RESET}"
    log_info "架构: ${CYAN}${ARCH_NAME}${RESET}"
    log_info "包管理器: ${CYAN}${PKG_MANAGER}${RESET}"
}

# ==================== 检查是否为root用户 ====================
check_root() {
    if [ $EUID -ne 0 ]; then
        log_error "请使用root用户执行该脚本 (sudo ./install_trzsz.bash)"
        exit 1
    fi
}

# ==================== 安装trzsz ====================
install_trzsz() {
    log_step "1. 开始安装 trzsz"

    # 版本和下载地址
    VERSION="1.2.0"
    DOWNLOAD_URL="https://githubfast.com/trzsz/trzsz-go/releases/download/v${VERSION}"
    PKG_FILE="trzsz_${VERSION}_linux_${ARCH_NAME}.${PKG_SUFFIX}"
    PKG_URL="${DOWNLOAD_URL}/${PKG_FILE}"

    # 检查是否已安装
    if command -v trzsz &> /dev/null; then
        CURRENT_VERSION=$(trzsz --version 2>/dev/null | head -n1)
        log_warn "trzsz 已安装: ${CURRENT_VERSION}"
        read -rp "是否重新安装？(y/n): " confirm
        if [[ "${confirm}" != "y" && "${confirm}" != "Y" ]]; then
            log_info "取消安装"
            return 0
        fi
    fi

    # 下载安装包
    log_step "2. 下载安装包 ${PKG_FILE}"
    if [ -f "${PKG_FILE}" ]; then
        log_warn "安装包 ${PKG_FILE} 已存在，跳过下载"
    else
        wget "${PKG_URL}" -O "${PKG_FILE}" --quiet
        check_result "下载安装包"
    fi

    # 安装
    log_step "3. 安装 trzsz"
    case "${PKG_MANAGER}" in
        apt)
            sudo dpkg -i "${PKG_FILE}"
            check_result "安装 trzsz"
            sudo apt-get install -f -y > /dev/null 2>&1
            ;;
        yum)
            sudo rpm -i "${PKG_FILE}"
            check_result "安装 trzsz"
            ;;
        dnf)
            sudo dnf localinstall -y "${PKG_FILE}" > /dev/null 2>&1
            check_result "安装 trzsz"
            ;;
    esac

    # 清理安装包
    log_step "4. 清理安装包"
    rm -f "${PKG_FILE}"
    log_info "已删除安装包 ${PKG_FILE}"

    # 验证安装
    log_step "5. 验证安装"
    if command -v trzsz &> /dev/null; then
        INSTALLED_VERSION=$(trzsz --version 2>/dev/null | head -n1)
        log_info "trzsz 安装成功: ${CYAN}${INSTALLED_VERSION}${RESET}"
    else
        log_error "trzsz 安装失败"
        exit 1
    fi

    echo ""
    log_info "${CYAN}使用说明:${RESET}"
    echo "  1. trzsz 用于在终端中传输文件"
    echo "  2. 安装后自动配置好 trzsz 支持"
    echo "  3. 在终端中使用 trz 上传文件，tsz 下载文件"
}

# ==================== 卸载trzsz ====================
uninstall_trzsz() {
    log_step "1. 开始卸载 trzsz"

    # 检查是否已安装
    if ! command -v trzsz &> /dev/null; then
        log_warn "trzsz 未安装，无需卸载"
        return 0
    fi

    CURRENT_VERSION=$(trzsz --version 2>/dev/null | head -n1)
    log_info "当前版本: ${CURRENT_VERSION}"

    read -rp "确认卸载 trzsz？(y/n): " confirm
    if [[ "${confirm}" != "y" && "${confirm}" != "Y" ]]; then
        log_info "取消卸载"
        return 0
    fi

    # 卸载
    log_step "2. 卸载 trzsz"
    case "${PKG_MANAGER}" in
        apt)
            sudo dpkg -r trzsz
            check_result "卸载 trzsz"
            ;;
        yum)
            sudo rpm -e trzsz
            check_result "卸载 trzsz"
            ;;
        dnf)
            sudo dnf remove -y trzsz > /dev/null 2>&1
            check_result "卸载 trzsz"
            ;;
    esac

    # 验证卸载
    log_step "3. 验证卸载"
    if ! command -v trzsz &> /dev/null; then
        log_info "trzsz 卸载成功"
    else
        log_error "trzsz 卸载失败"
        exit 1
    fi
}

# ==================== 显示帮助 ====================
show_help() {
    echo -e "${CYAN}用法:${RESET} $0 [选项]"
    echo ""
    echo -e "${CYAN}选项:${RESET}"
    echo "  install    安装 trzsz"
    echo "  uninstall  卸载 trzsz"
    echo "  -h,--help  显示此帮助信息"
    echo ""
    echo -e "${CYAN}示例:${RESET}"
    echo "  sudo $0 install"
    echo "  sudo $0 uninstall"
}

# ==================== 主函数 ====================
main() {
    echo -e "${CYAN}================================================================${RESET}"
    echo -e "${CYAN}          trzsz 安装与卸载工具${RESET}"
    echo -e "${CYAN}================================================================${RESET}"
    echo ""

    # 检查参数
    if [ $# -eq 0 ]; then
        show_help
        exit 1
    fi

    case "$1" in
        install)
            check_root
            detect_system
            install_trzsz
            ;;
        uninstall)
            check_root
            detect_system
            uninstall_trzsz
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
