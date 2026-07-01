#!/bin/bash
#
#********************************************************************
#Author:           YiLing Wu (hj)
#email:            huangjing510@126.com
#Date:             2026-07-01
#FileName:         php_manager.bash
#URL:              https://script.huangjingblog.cn
#Description:      PHP编译安装与卸载工具，支持Ubuntu/CentOS，自动检测系统和包管理器
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
        *)
            log_error "不支持的架构: ${ARCH}"
            exit 1
            ;;
    esac

    # 检测系统类型和包管理器
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
    elif command -v yum &> /dev/null; then
        PKG_MANAGER="yum"
    elif command -v dnf &> /dev/null; then
        PKG_MANAGER="dnf"
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
        log_error "请使用root用户执行该脚本 (sudo ./php_manager.bash)"
        exit 1
    fi
}

# ==================== 检测PHP依赖 ====================
detect_php_deps() {
    log_step "检测PHP编译依赖"

    # 根据包管理器选择依赖
    case "${PKG_MANAGER}" in
        apt)
            ALL_DEPS="build-essential autoconf automake libtool pkg-config \
                libxml2-dev libbz2-dev libssl-dev libffi-dev libonig-dev libzip-dev \
                libcurl4-openssl-dev libjpeg-dev libpng-dev libwebp-dev libsqlite3-dev"
            ;;
        yum|dnf)
            ALL_DEPS="gcc gcc-c++ make autoconf automake libtool pkgconfig \
                libxml2-devel bzip2-devel openssl-devel libffi-devel oniguruma-devel libzip-devel \
                curl-devel libjpeg-devel libpng-devel libwebp-devel sqlite-devel"
            ;;
    esac
}

# ==================== 安装PHP ====================
install_php() {
    log_step "1. 开始安装 PHP"

    # 版本和下载地址
    INSTALL_PATH="/usr/local"
    DOWNLOAD_PATH="${INSTALL_PATH}/src"
    PHP_CONFIG="/etc/php"

    # 输入版本号
    DEFAULT_VERSION="8.4.10"
    read -rp "请输入PHP版本号 [${DEFAULT_VERSION}]: " INPUT_VERSION
    PHP_VERSION="${INPUT_VERSION:-${DEFAULT_VERSION}}"

    PHP_TARBALL="php-${PHP_VERSION}.tar.gz"
    PHP_SRC_DIR="${DOWNLOAD_PATH}/php-${PHP_VERSION}"
    PHP_PREFIX="${INSTALL_PATH}/php"
    PHP_URL="https://www.php.net/distributions/${PHP_TARBALL}"

    # 检查是否已安装
    if command -v php &> /dev/null; then
        CURRENT_VERSION=$(php -v 2>/dev/null | head -n1)
        log_warn "PHP 已安装: ${CURRENT_VERSION}"
        read -rp "是否重新安装？(y/n): " confirm
        if [[ "${confirm}" != "y" && "${confirm}" != "Y" ]]; then
            log_info "取消安装"
            return 0
        fi
    fi

    # 安装依赖
    log_step "2. 安装编译依赖"
    case "${PKG_MANAGER}" in
        apt)
            apt-get update -qq
            apt-get install -y ${ALL_DEPS}
            ;;
        yum)
            yum install -y ${ALL_DEPS}
            ;;
        dnf)
            dnf install -y ${ALL_DEPS}
            ;;
    esac
    check_result "安装编译依赖"

    # 下载源码包
    log_step "3. 下载源码包 ${PHP_TARBALL}"
    mkdir -p "${DOWNLOAD_PATH}"
    cd "${DOWNLOAD_PATH}"
    if [ -f "${PHP_TARBALL}" ]; then
        log_warn "源码包已存在，跳过下载: ${PHP_TARBALL}"
    else
        wget "${PHP_URL}" -q
        check_result "下载源码包"
    fi

    # 解压源码包
    log_step "4. 解压源码包"
    if [ -d "${PHP_SRC_DIR}" ]; then
        log_warn "源码目录已存在，跳过解压: ${PHP_SRC_DIR}"
    else
        tar -zxf "${PHP_TARBALL}"
        check_result "解压源码包"
    fi

    # 编译安装
    log_step "5. 编译安装 PHP（请耐心等待...）"
    cd "${PHP_SRC_DIR}"
    ./configure --prefix="${PHP_PREFIX}" --sysconfdir="${PHP_CONFIG}" \
        --with-openssl --with-zlib --with-bz2 --with-curl --enable-bcmath \
        --enable-gd --with-webp --with-jpeg --with-mhash --enable-mbstring \
        --with-imap-ssl --with-mysqli --enable-exif --with-ffi --with-zip \
        --enable-sockets --with-pcre-jit --enable-fpm --with-pdo-mysql --enable-pcntl
    check_result "配置编译"

    make -j"$(nproc)"
    check_result "编译"

    make install
    check_result "安装"

    # 创建www用户和用户组
    log_step "6. 创建www用户和用户组"
    if ! getent group www > /dev/null 2>&1; then
        groupadd www
    fi
    if ! id www > /dev/null 2>&1; then
        useradd -g www -s /sbin/nologin www
    fi
    check_result "创建www用户"

    # 复制配置文件
    log_step "7. 复制配置文件"
    cp "${PHP_SRC_DIR}/php.ini-development" "${PHP_PREFIX}/lib/php.ini"
    cp "${PHP_CONFIG}/php-fpm.conf.default" "${PHP_CONFIG}/php-fpm.conf"
    cp "${PHP_CONFIG}/php-fpm.d/www.conf.default" "${PHP_CONFIG}/php-fpm.d/www.conf"
    check_result "复制配置文件"

    # 配置环境变量
    log_step "8. 配置环境变量"
    profile_d="/etc/profile.d"
    php_env_file="${profile_d}/php.sh"

    mkdir -p "${profile_d}"
    cat > "${php_env_file}" <<EOF
# PHP Environment
export PATH=\$PATH:${PHP_PREFIX}/bin:${PHP_PREFIX}/sbin
EOF
    chmod +x "${php_env_file}"
    source "${php_env_file}"
    check_result "配置环境变量"

    # 修改配置文件
    log_step "9. 修改PHP配置文件"
    mkdir -p "${PHP_PREFIX}/tmp"
    chmod -R 755 "${PHP_PREFIX}/tmp"

    sed -i 's@;session.save_path = "/tmp"@session.save_path = "/usr/local/php/tmp"@' "${PHP_PREFIX}/lib/php.ini"
    sed -i 's/^user = .*/user = www/' "${PHP_CONFIG}/php-fpm.d/www.conf"
    sed -i 's/^group = .*/group = www/' "${PHP_CONFIG}/php-fpm.d/www.conf"

    # 修改常用PHP参数
    sed -i 's/^post_max_size = .*/post_max_size = 16M/' "${PHP_PREFIX}/lib/php.ini"
    sed -i 's/^max_execution_time = .*/max_execution_time = 300/' "${PHP_PREFIX}/lib/php.ini"
    sed -i 's/^max_input_time = .*/max_input_time = 300/' "${PHP_PREFIX}/lib/php.ini"
    check_result "修改配置文件"

    # 配置systemd启动脚本
    log_step "10. 配置systemd启动脚本"
    cat >/usr/lib/systemd/system/php-fpm.service <<EOF
[Unit]
Description=php-fpm
After=syslog.target network.target

[Service]
Type=forking
ExecStart=${PHP_PREFIX}/sbin/php-fpm
ExecReload=/bin/kill -USR2 \$MAINPID
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
    check_result "创建systemd服务"

    systemctl daemon-reload
    systemctl enable php-fpm
    systemctl start php-fpm
    systemctl status php-fpm
    check_result "启动php-fpm服务"

    # 验证安装
    log_step "11. 验证安装"
    if command -v php &> /dev/null; then
        INSTALLED_VERSION=$(php -v 2>/dev/null | head -n1)
        log_info "PHP 安装成功: ${CYAN}${INSTALLED_VERSION}${RESET}"
    else
        log_error "PHP 安装失败"
        exit 1
    fi

    echo ""
    log_info "${CYAN}使用说明:${RESET}"
    echo "  1. PHP已编译安装到: ${PHP_PREFIX}"
    echo "  2. PHP配置文件: ${PHP_PREFIX}/lib/php.ini"
    echo "  3. FPM配置目录: ${PHP_CONFIG}"
    echo "  4. 使用 systemctl start php-fpm 启动服务"
    echo "  5. 使用 systemctl stop php-fpm 停止服务"
    echo "  6. 重启命令: systemctl restart php-fpm"
}

# ==================== 卸载PHP ====================
uninstall_php() {
    log_step "1. 开始卸载 PHP"

    # 检查是否已安装（通过检测安装目录）
    PHP_PREFIX="/usr/local/php"
    PHP_CONFIG="/etc/php"

    if [ ! -d "${PHP_PREFIX}" ]; then
        log_warn "PHP 未安装，无需卸载"
        return 0
    fi

    # 获取已安装版本
    if [ -x "${PHP_PREFIX}/bin/php" ]; then
        CURRENT_VERSION=$("${PHP_PREFIX}/bin/php" -v 2>/dev/null | head -n1)
        log_info "当前版本: ${CURRENT_VERSION}"
    else
        log_info "检测到安装目录，但 php 可执行文件不存在"
    fi

    read -rp "确认卸载 PHP？(y/n): " confirm
    if [[ "${confirm}" != "y" && "${confirm}" != "Y" ]]; then
        log_info "取消卸载"
        return 0
    fi

    # 停止服务
    log_step "2. 停止PHP-FPM服务"
    if systemctl is-active --quiet php-fpm; then
        systemctl stop php-fpm
        check_result "停止php-fpm服务"
    fi

    # 禁用服务
    log_step "3. 禁用systemd服务"
    if systemctl is-enabled --quiet php-fpm; then
        systemctl disable php-fpm
        check_result "禁用php-fpm服务"
    fi

    # 删除systemd服务文件
    log_step "4. 删除systemd服务文件"
    rm -f /usr/lib/systemd/system/php-fpm.service
    systemctl daemon-reload
    check_result "删除systemd服务"

    # 删除PHP安装目录
    log_step "5. 删除PHP安装目录"
    rm -rf "${PHP_PREFIX}"
    rm -rf /usr/local/php-*
    check_result "删除PHP安装目录"

    # 删除配置文件
    log_step "6. 删除配置文件"
    rm -rf "${PHP_CONFIG}"
    check_result "删除配置文件"

    # 删除环境变量
    log_step "7. 清理环境变量"
    php_env_file="/etc/profile.d/php.sh"
    if [ -f "${php_env_file}" ]; then
        rm -f "${php_env_file}"
        check_result "清理环境变量"
    fi

    # 删除www用户（如果有）
    log_step "8. 删除www用户"
    if id www > /dev/null 2>&1; then
        userdel www 2>/dev/null || true
    fi
    if getent group www > /dev/null 2>&1; then
        groupdel www 2>/dev/null || true
    fi
    check_result "删除www用户"

    # 验证卸载
    log_step "9. 验证卸载"
    if [ ! -d "${PHP_PREFIX}" ]; then
        log_info "PHP 卸载成功"
    else
        log_error "PHP 卸载可能不完整"
    fi
}

# ==================== 显示帮助 ====================
show_help() {
    echo -e "${CYAN}用法:${RESET} $0 [选项]"
    echo ""
    echo -e "${CYAN}选项:${RESET}"
    echo "  install    安装 PHP (源码编译) [默认]"
    echo "  uninstall  卸载 PHP"
    echo "  -h,--help  显示此帮助信息"
    echo ""
    echo -e "${CYAN}示例:${RESET}"
    echo "  sudo $0 install"
    echo "  sudo $0 uninstall"
    echo ""
    echo -e "${CYAN}说明:${RESET}"
    echo "  - 支持 Ubuntu/Debian/CentOS/RHEL 系统"
    echo "  - 自动检测包管理器 (apt/yum/dnf)"
    echo "  - 安装方式为源码编译安装"
    echo "  - 安装时可指定版本，默认 8.4.10"
    echo "  - 安装路径: /usr/local/php"
    echo "  - 配置文件: /etc/php"
}

# ==================== 主函数 ====================
main() {
    echo -e "${CYAN}================================================================${RESET}"
    echo -e "${CYAN}          PHP 安装与卸载工具${RESET}"
    echo -e "${CYAN}================================================================${RESET}"
    echo ""

    # 默认执行安装
    if [ $# -eq 0 ]; then
        set -- install
    fi

    case "$1" in
        install)
            check_root
            detect_system
            detect_php_deps
            install_php
            ;;
        uninstall)
            check_root
            detect_system
            uninstall_php
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
