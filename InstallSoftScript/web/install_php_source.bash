#!/bin/bash
#
#********************************************************************
#Author:           YiLing Wu (hj)
#email:            huangjing510@126.com
#Date:             2026-07-01
#FileName:         install_php_source.bash
#URL:              https://script.huangjingblog.cn
#Description:      PHP编译安装与卸载工具，仅支持Ubuntu/Debian系统
#Copyright (C):    2026 All rights reserved
#********************************************************************

# 颜色定义
GREEN="echo -e \E[32;1m"
RED="echo -e \E[31;1m"
YELLOW="echo -e \E[33;1m"
CYAN="echo -e \E[36;1m"
END="\E[0m"

# 日志函数
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
    $GREEN "检测系统信息" ; echo -e "${END}"

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
            color "不支持的架构: ${ARCH}" 1
            exit 1
            ;;
    esac

    # 检测系统类型
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_ID="${ID}"
        OS_NAME="${PRETTY_NAME}"
    else
        color "无法检测系统类型，缺少 /etc/os-release 文件" 1
        exit 1
    fi

    # 仅支持 Ubuntu/Debian
    if ! command -v apt &> /dev/null; then
        color "此脚本仅支持 Ubuntu/Debian 系统 (未检测到 apt)" 1
        exit 1
    fi

    color "系统: ${OS_NAME}" 0
    color "架构: ${ARCH_NAME}" 0
}

# 检查是否为root用户
check_root() {
    if [ $EUID -ne 0 ]; then
        color "请使用root用户执行该脚本 (sudo ./install_php_source.bash)" 1
        exit 1
    fi
}

# 检测PHP依赖
detect_php_deps() {
    $GREEN "检测PHP编译依赖" ; echo -e "${END}"
    ALL_DEPS="build-essential autoconf automake libtool pkg-config \
        libxml2-dev libbz2-dev libssl-dev libffi-dev libonig-dev libzip-dev \
        libcurl4-openssl-dev libjpeg-dev libpng-dev libwebp-dev libsqlite3-dev"
}

# 安装PHP
install_php() {
    $GREEN "1. 开始安装 PHP" ; echo -e "${END}"

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
        color "PHP 已安装: ${CURRENT_VERSION}" 2
        read -rp "是否重新安装？(y/n): " confirm
        if [[ "${confirm}" != "y" && "${confirm}" != "Y" ]]; then
            color "取消安装" 0
            return 0
        fi
    fi

    # 安装依赖
    $GREEN "2. 安装编译依赖" ; echo -e "${END}"
    apt-get update -qq
    apt-get install -y ${ALL_DEPS}
    check_result "安装编译依赖"

    # 下载源码包
    $GREEN "3. 下载源码包 ${PHP_TARBALL}" ; echo -e "${END}"
    mkdir -p "${DOWNLOAD_PATH}"
    cd "${DOWNLOAD_PATH}"
    if [ -f "${PHP_TARBALL}" ]; then
        color "源码包已存在，跳过下载: ${PHP_TARBALL}" 2
    else
        wget "${PHP_URL}" -q
        check_result "下载源码包"
    fi

    # 解压源码包
    $GREEN "4. 解压源码包" ; echo -e "${END}"
    if [ -d "${PHP_SRC_DIR}" ]; then
        color "源码目录已存在，跳过解压: ${PHP_SRC_DIR}" 2
    else
        tar -zxf "${PHP_TARBALL}"
        check_result "解压源码包"
    fi

    # 编译安装
    $GREEN "5. 编译安装 PHP（请耐心等待...）" ; echo -e "${END}"
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
    $GREEN "6. 创建www用户和用户组" ; echo -e "${END}"
    if ! getent group www > /dev/null 2>&1; then
        groupadd www
    fi
    if ! id www > /dev/null 2>&1; then
        useradd -g www -s /sbin/nologin www
    fi
    check_result "创建www用户"

    # 复制配置文件
    $GREEN "7. 复制配置文件" ; echo -e "${END}"
    cp "${PHP_SRC_DIR}/php.ini-development" "${PHP_PREFIX}/lib/php.ini"
    cp "${PHP_CONFIG}/php-fpm.conf.default" "${PHP_CONFIG}/php-fpm.conf"
    cp "${PHP_CONFIG}/php-fpm.d/www.conf.default" "${PHP_CONFIG}/php-fpm.d/www.conf"
    check_result "复制配置文件"

    # 配置环境变量
    $GREEN "8. 配置环境变量" ; echo -e "${END}"
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
    $GREEN "9. 修改PHP配置文件" ; echo -e "${END}"
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
    $GREEN "10. 配置systemd启动脚本" ; echo -e "${END}"
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
    $GREEN "11. 验证安装" ; echo -e "${END}"
    if command -v php &> /dev/null; then
        INSTALLED_VERSION=$(php -v 2>/dev/null | head -n1)
        color "PHP 安装成功: ${INSTALLED_VERSION}" 0
    else
        color "PHP 安装失败" 1
        exit 1
    fi

    echo ""
    echo "  使用说明:"
    echo "  1. PHP已编译安装到: ${PHP_PREFIX}"
    echo "  2. PHP配置文件: ${PHP_PREFIX}/lib/php.ini"
    echo "  3. FPM配置目录: ${PHP_CONFIG}"
    echo "  4. 使用 systemctl start php-fpm 启动服务"
    echo "  5. 使用 systemctl stop php-fpm 停止服务"
    echo "  6. 重启命令: systemctl restart php-fpm"
}

# 卸载PHP
uninstall_php() {
    $GREEN "1. 开始卸载 PHP" ; echo -e "${END}"

    # 检查是否已安装（通过检测安装目录）
    PHP_PREFIX="/usr/local/php"
    PHP_CONFIG="/etc/php"

    if [ ! -d "${PHP_PREFIX}" ]; then
        color "PHP 未安装，无需卸载" 2
        return 0
    fi

    # 获取已安装版本
    if [ -x "${PHP_PREFIX}/bin/php" ]; then
        CURRENT_VERSION=$("${PHP_PREFIX}/bin/php" -v 2>/dev/null | head -n1)
        color "当前版本: ${CURRENT_VERSION}" 0
    else
        color "检测到安装目录，但 php 可执行文件不存在" 0
    fi

    read -rp "确认卸载 PHP？(y/n): " confirm
    if [[ "${confirm}" != "y" && "${confirm}" != "Y" ]]; then
        color "取消卸载" 0
        return 0
    fi

    # 停止服务
    $GREEN "2. 停止PHP-FPM服务" ; echo -e "${END}"
    if systemctl is-active --quiet php-fpm; then
        systemctl stop php-fpm
        check_result "停止php-fpm服务"
    fi

    # 禁用服务
    $GREEN "3. 禁用systemd服务" ; echo -e "${END}"
    if systemctl is-enabled --quiet php-fpm; then
        systemctl disable php-fpm
        check_result "禁用php-fpm服务"
    fi

    # 删除systemd服务文件
    $GREEN "4. 删除systemd服务文件" ; echo -e "${END}"
    rm -f /usr/lib/systemd/system/php-fpm.service
    systemctl daemon-reload
    check_result "删除systemd服务"

    # 删除PHP安装目录
    $GREEN "5. 删除PHP安装目录" ; echo -e "${END}"
    rm -rf "${PHP_PREFIX}"
    rm -rf /usr/local/php-*
    check_result "删除PHP安装目录"

    # 删除配置文件
    $GREEN "6. 删除配置文件" ; echo -e "${END}"
    rm -rf "${PHP_CONFIG}"
    check_result "删除配置文件"

    # 删除环境变量
    $GREEN "7. 清理环境变量" ; echo -e "${END}"
    php_env_file="/etc/profile.d/php.sh"
    if [ -f "${php_env_file}" ]; then
        rm -f "${php_env_file}"
        check_result "清理环境变量"
    fi

    # 删除www用户
    $GREEN "8. 删除www用户" ; echo -e "${END}"
    if id www > /dev/null 2>&1; then
        userdel www 2>/dev/null || true
    fi
    if getent group www > /dev/null 2>&1; then
        groupdel www 2>/dev/null || true
    fi
    check_result "删除www用户"

    # 验证卸载
    $GREEN "9. 验证卸载" ; echo -e "${END}"
    if [ ! -d "${PHP_PREFIX}" ]; then
        color "PHP 卸载成功" 0
    else
        color "PHP 卸载可能不完整" 1
    fi
}

# 显示帮助
show_help() {
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  install    安装 PHP (源码编译) [默认]"
    echo "  uninstall  卸载 PHP"
    echo "  -h,--help  显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  sudo $0 install"
    echo "  sudo $0 uninstall"
    echo ""
    echo "说明:"
    echo "  - 仅支持 Ubuntu/Debian 系统"
    echo "  - 安装方式为源码编译安装"
    echo "  - 安装时可指定版本，默认 8.4.10"
    echo "  - 安装路径: /usr/local/php"
    echo "  - 配置文件: /etc/php"
}

# 主函数
main() {
    echo "================================================================"
    echo "          PHP 安装与卸载工具"
    echo "================================================================"
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
