#!/bin/bash
#
#********************************************************************
#Author:           YiLing Wu (hj)
#email:            huangjing510@126.com
#Date:             2026-07-02
#FileName:         install_zabbix.bash
#URL:              https://script.huangjingblog.cn
#Description:      Zabbix 7.0监控系统一键安装与卸载工具（仅适配Ubuntu/Debian）
#                   - 数据库: MySQL 8.0(系统仓库)
#                   - Web服务: Nginx + PHP-FPM
#                   - 前端: Zabbix Frontend (PHP)
#                   - 代理: Zabbix Agent2
#Copyright (C):    2026 All rights reserved
#********************************************************************

# ==================== 默认配置 ====================
# zabbix版本选项
ZABBIX_VERSION="7.0"
#ZABBIX_VERSION="7.2"
#ZABBIX_VERSION="7.4"
#ZABBIX_VERSION="8.0"

ZABBIX_DB_NAME="zabbix"
ZABBIX_DB_USER="zabbix"
ZABBIX_DB_PASS="zabbix123"
MYSQL_ROOT_PASS=""
ZABBIX_SERVER_HOST="localhost"
ZABBIX_SERVER_PORT="80"
ZABBIX_DOMAIN=""

# PHP版本选择
PHP_VERSION="8.0"
#PHP_VERSION="8.2"
#PHP_VERSION="8.3"
#PHP_VERSION="8.4"
#PHP_VERSION="8.5"


# ==================== 源配置选择 ====================
# 使用方式: 取消注释需要的源类型，注释掉不需要的源类型
# Zabbix 源配置（二选一）
#USE_ZABBIX_OFFICIAL=true        # 使用官方源
USE_ZABBIX_NEXUS=true          # 使用 Nexus 私有源

# PHP 源配置（二选一）
#USE_PHP_OFFICIAL=true           # 使用官方 PPA 源
USE_PHP_NEXUS=true             # 使用 Nexus 私有源

# Nexus 私有源配置
NEXUS_URL="http://nexus.huang.org"

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

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_ID="${ID}"
        OS_VERSION="${VERSION_ID}"
        OS_NAME="${PRETTY_NAME}"
    else
        log_error "无法检测系统类型"
        exit 1
    fi

    # 检测包管理器
    if command -v apt &> /dev/null; then
        PKG_MANAGER="apt"
    else
        log_error "当前脚本仅适配Ubuntu/Debian系统（apt），不支持其他包管理器"
        exit 1
    fi

    log_info "系统: ${CYAN}${OS_NAME}${RESET}"
    log_info "包管理器: ${CYAN}${PKG_MANAGER}${RESET}"
}

# ==================== 检查是否为root用户 ====================
check_root() {
    if [ $EUID -ne 0 ]; then
        log_error "请使用root用户执行该脚本 (sudo ./install_zabbix.bash)"
        exit 1
    fi
}

# ==================== 检查MySQL是否已安装 ====================
check_mysql_installed() {
    # 检查mysql/mysqld二进制文件是否实际存在且可执行
    if [ -x "$(command -v mysql 2>/dev/null)" ] || [ -x "$(command -v mysqld 2>/dev/null)" ]; then
        return 0
    fi
    # 检查dpkg中mysql-server包是否处于已安装状态
    if dpkg -l mysql-server 2>/dev/null | grep -q "^ii"; then
        return 0
    fi
    if dpkg -l mariadb-server 2>/dev/null | grep -q "^ii"; then
        return 0
    fi
    return 1
}

# ==================== 检查MySQL服务是否运行 ====================
check_mysql_running() {
    # 检查mysqld服务状态
    if systemctl is-active --quiet mysqld 2>/dev/null || systemctl is-active --quiet mysql 2>/dev/null; then
        return 0
    fi
    # 检查mariadb服务状态
    if systemctl is-active --quiet mariadb 2>/dev/null; then
        return 0
    fi
    # 尝试通过socket连接测试
    if mysql -u root -e "SELECT 1" &>/dev/null; then
        return 0
    fi
    return 1
}

# ==================== 安装MySQL ====================
install_mysql() {
    log_step "安装MySQL"

    # 获取MySQL root密码
    echo ""
    read -rp "请设置MySQL root密码 (回车默认随机生成): " mysql_root_password
    if [ -z "$mysql_root_password" ]; then
        mysql_root_password=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 8)
        log_info "MySQL root密码: ${YELLOW}${mysql_root_password}${RESET}"
    fi

    # 清理旧的MySQL/MariaDB安装
    log_info "清理旧的MySQL/MariaDB安装"
    systemctl stop mysqld 2>/dev/null || systemctl stop mysql 2>/dev/null || systemctl stop mariadb 2>/dev/null
    systemctl disable mysqld 2>/dev/null || systemctl disable mysql 2>/dev/null || systemctl disable mariadb 2>/dev/null

    # 清理系统默认mysql和mariadb
    dpkg -l | grep -E "mysql|mariadb" | awk '{print $2}' | xargs dpkg --purge --force-all &>/dev/null

    # Ubuntu/Debian系统 - 使用系统自带MySQL仓库（避免官方源GPG密钥过期问题）
    log_info "使用系统仓库安装MySQL"

    # 先清理可能存在的MySQL官方APT源残留（防止GPG错误干扰）
    rm -f /etc/apt/sources.list.d/mysql.list 2>/dev/null
    rm -f /etc/apt/sources.list.d/mysql-source.list 2>/dev/null
    rm -f /etc/apt/sources.list.d/mysql.list.dpkg-old 2>/dev/null

    # 修复系统破损的依赖状态（前次安装失败可能留下残留）
    log_info "修复系统破损依赖"
    dpkg --configure -a 2>/dev/null
    apt --fix-broken install -y 2>/dev/null

    # 更新包列表并安装MySQL
    apt update -qq
    apt install -y mysql-server

    check_result "安装MySQL"

    # 启动MySQL服务
    log_info "启动MySQL服务"
    systemctl start mysql 2>/dev/null || systemctl start mysqld 2>/dev/null
    check_result "启动MySQL服务"

    systemctl enable mysql 2>/dev/null || systemctl enable mysqld 2>/dev/null

    # 修改root密码
    log_info "配置MySQL root密码"

    # 尝试多种方式登录并设置密码
    # 方式1: 尝试通过socket认证直接登录（Ubuntu系统包默认方式）
    if mysql -uroot -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${mysql_root_password}';" 2>/dev/null; then
        log_info "通过socket认证设置密码成功"
    else
        # 方式2: 尝试使用临时密码登录（官方包方式）
        local temp_password=""
        if [ -f /var/log/mysqld.log ]; then
            temp_password=$(grep 'temporary password' /var/log/mysqld.log | awk '{print $NF}' | tail -1)
        elif [ -f /var/log/mysql/mysqld.log ]; then
            temp_password=$(grep 'temporary password' /var/log/mysql/mysqld.log | awk '{print $NF}' | tail -1)
        fi

        if [ -n "$temp_password" ]; then
            mysql --connect-expired-password -uroot -p"${temp_password}" -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${mysql_root_password}';" 2>/dev/null
        else
            # 方式3: 无密码登录
            mysql -uroot -e "SET PASSWORD FOR 'root'@'localhost' = '${mysql_root_password}';" 2>/dev/null
        fi
    fi

    # 允许远程连接
    mysql -uroot -p"${mysql_root_password}" -e "UPDATE user SET host='%' WHERE user='root' AND host='localhost'; FLUSH PRIVILEGES;" 2>/dev/null

    # 设置密码策略（可选，允许简单密码）
    mysql -uroot -p"${mysql_root_password}" -e "SET GLOBAL validate_password.policy=LOW; SET GLOBAL validate_password.length=4;" 2>/dev/null

    log_info "MySQL安装完成"
    log_info "MySQL root密码: ${YELLOW}${mysql_root_password}${RESET}"

    # 设置全局变量供后续步骤使用
    MYSQL_ROOT_PASS="${mysql_root_password}"
}

# ==================== 检查Zabbix是否已安装 ====================
check_zabbix_installed() {
    # 检查zabbix_server二进制文件是否存在
    if [ -x "$(command -v zabbix_server 2>/dev/null)" ]; then
        return 0
    fi
    # 检查dpkg中zabbix-server包是否处于已安装状态(ii)
    if dpkg -l zabbix-server-mysql 2>/dev/null | grep -q "^ii"; then
        return 0
    fi
    return 1
}

# ==================== 获取本机IP地址 ====================
get_local_ip() {
    local ip_addr
    ip_addr=$(hostname -I | awk '{print $1}')
    if [ -z "$ip_addr" ]; then
        ip_addr=$(ip route get 1 | grep -oP 'src \K\S+')
    fi
    if [ -z "$ip_addr" ]; then
        ip_addr="127.0.0.1"
    fi
    echo "$ip_addr"
}

# ==================== 配置域名 ====================
setup_domain() {
    log_step "配置访问域名"

    local local_ip=$(get_local_ip)

    echo ""
    echo -e "${CYAN}当前本机IP地址: ${BOLD}${local_ip}${RESET}"
    echo ""
    echo "  请输入Zabbix访问域名或IP地址"
    echo "  支持以下格式:"
    echo "    - 域名: zabbix.example.com"
    echo "    - IP地址: ${local_ip}"
    echo ""
    read -rp "请输入域名/IP (回车默认使用 ${local_ip}): " input_domain
    ZABBIX_DOMAIN="${input_domain:-$local_ip}"

    log_info "访问地址: ${CYAN}http://${ZABBIX_DOMAIN}/"
}

# ==================== 配置Zabbix源 ====================
setup_zabbix_repo() {
    log_step "1. 配置Zabbix源"

    # 检查是否已配置（存在且包可用才跳过）
    if [ -f /etc/apt/sources.list.d/zabbix.list ]; then
        if apt-cache policy zabbix-server-mysql 2>/dev/null | grep -q "Candidate:"; then
            log_info "Zabbix源已配置且可用，跳过配置"
            return 0
        fi
        log_warn "Zabbix源存在但不可用，重新配置"
    fi

    # ==================== Zabbix 源配置（二选一） ====================
    # 使用方式: 在上方配置区域选择 USE_ZABBIX_OFFICIAL 或 USE_ZABBIX_NEXUS

    if [ "$USE_ZABBIX_NEXUS" == "true" ]; then
        # ---------- Nexus 私有源 ----------
        log_info "使用 Nexus 私有源: ${NEXUS_URL}"

        # 导入 Zabbix 签名密钥（从官方下载）
        log_info "导入 Zabbix 签名密钥"
        rm -f /usr/share/keyrings/nexus-zabbix.gpg 2>/dev/null
        curl -fsSL "https://repo.zabbix.com/zabbix/APT-GPG-KEY" | gpg --dearmor -o /usr/share/keyrings/nexus-zabbix.gpg

        # 创建源文件
        log_info "创建 Zabbix 源文件"
        cat > /etc/apt/sources.list.d/zabbix.list <<EOF
deb [trusted=yes] ${NEXUS_URL}/repository/zabbix-${ZABBIX_VERSION}-apt/ $(lsb_release -cs) main
EOF

    elif [ "$USE_ZABBIX_OFFICIAL" == "true" ]; then
        # ---------- 官方源 ----------
        log_info "使用 Zabbix 官方源"

        # Ubuntu/Debian系统 - 安装deb包获取GPG密钥，手动创建源文件
        local zabbix_deb_url=""
        local zabbix_codename=""

        if [[ "$OS_ID" == "ubuntu" ]]; then
            zabbix_codename="${UBUNTU_CODENAME:-jammy}"
            zabbix_deb_url="https://repo.zabbix.com/zabbix/${ZABBIX_VERSION}/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_${ZABBIX_VERSION}+ubuntu${OS_VERSION}_all.deb"
        elif [[ "$OS_ID" == "debian" ]]; then
            local major_version="${OS_VERSION%%.*}"
            zabbix_codename="bookworm"
            [[ "$major_version" == "11" ]] && zabbix_codename="bullseye"
            zabbix_deb_url="https://repo.zabbix.com/zabbix/${ZABBIX_VERSION}/debian/pool/main/z/zabbix-release/zabbix-release_latest_${ZABBIX_VERSION}+debian${major_version}_all.deb"
        else
            log_error "不支持的Debian/Ubuntu系统: ${OS_ID}"
            exit 1
        fi

        # 下载并安装deb包（获取GPG密钥）
        log_info "下载并安装Zabbix源包"
        wget -q "${zabbix_deb_url}" -O /tmp/zabbix-release.deb || {
            log_error "下载Zabbix源包失败"
            exit 1
        }
        dpkg -i /tmp/zabbix-release.deb
        rm -f /tmp/zabbix-release.deb

        # 找到deb包安装的GPG密钥
        local keyring_path=""
        for f in /usr/share/keyrings/zabbix*.gpg /etc/apt/trusted.gpg.d/zabbix*.gpg; do
            [ -f "$f" ] && keyring_path="$f" && break
        done

        if [ -z "$keyring_path" ]; then
            log_error "GPG密钥未找到"
            exit 1
        fi
        log_info "GPG密钥: ${keyring_path}"

        # 创建源文件（deb包可能没有自动创建）
        if [ ! -f /etc/apt/sources.list.d/zabbix.list ]; then
            log_info "创建Zabbix源文件"
            cat > /etc/apt/sources.list.d/zabbix.list <<EOF
deb [signed-by=${keyring_path}] https://repo.zabbix.com/zabbix/${ZABBIX_VERSION}/ubuntu ${zabbix_codename} main
deb-src [signed-by=${keyring_path}] https://repo.zabbix.com/zabbix/${ZABBIX_VERSION}/ubuntu ${zabbix_codename} main
EOF
        fi

    else
        log_error "未选择 Zabbix 源类型，请在脚本配置区域设置 USE_ZABBIX_OFFICIAL 或 USE_ZABBIX_NEXUS"
        exit 1
    fi

    # 更新并验证
    log_info "更新包列表"
    apt update -qq 2>&1 | tail -5

    if ! apt-cache policy zabbix-server-mysql 2>/dev/null | grep -q "Candidate:.*${ZABBIX_VERSION}"; then
        log_error "Zabbix ${ZABBIX_VERSION} 源配置失败"
        log_info "当前候选版本:"
        apt-cache policy zabbix-server-mysql 2>/dev/null | head -5
        exit 1
    fi
    log_info "Zabbix源配置验证通过"

    log_info "Zabbix源配置完成"
}

# ==================== 安装Zabbix组件 ====================
install_zabbix_packages() {
    log_step "3. 安装Zabbix组件"

    # 清理可能残留的破损包状态
    for pkg in zabbix-agent2 nginx-core nginx; do
        if dpkg -l "$pkg" 2>/dev/null | grep -qE "^i[^i]"; then
            log_warn "清除残留的破损状态: ${pkg}"
            dpkg --purge --force-all "$pkg" 2>/dev/null
        fi
    done

    apt update -qq
    apt install -y \
        zabbix-server-mysql \
        zabbix-sql-scripts \
        zabbix-frontend-php \
        nginx \
        zabbix-agent2

    check_result "安装Zabbix组件"
}

# ==================== 确保MySQL安装并运行 ====================
ensure_mysql() {
    log_step "2. 安装MySQL数据库"

    # 检查MySQL是否安装
    if ! check_mysql_installed; then
        log_warn "MySQL未安装"
        echo ""
        read -rp "是否自动安装MySQL？(Y/n): " install_mysql_choice
        if [[ "${install_mysql_choice}" != "n" && "${install_mysql_choice}" != "N" ]]; then
            install_mysql
        else
            log_error "请先安装MySQL后重试"
            exit 1
        fi
    else
        # MySQL已安装，检查服务是否运行
        if ! check_mysql_running; then
            log_warn "MySQL已安装但服务未运行"
            echo ""
            read -rp "是否尝试启动MySQL服务？(Y/n): " start_mysql_choice
            if [[ "${start_mysql_choice}" != "n" && "${start_mysql_choice}" != "N" ]]; then
                log_info "启动MySQL服务"
                systemctl start mysql 2>/dev/null || systemctl start mysqld 2>/dev/null
                sleep 3
                # 再次检查
                if ! check_mysql_running; then
                    log_warn "MySQL服务启动失败，可能是旧版本残留"
                    echo ""
                    read -rp "是否重新安装MySQL（使用系统仓库）？(Y/n): " reinstall_mysql
                    if [[ "${reinstall_mysql}" != "n" && "${reinstall_mysql}" != "N" ]]; then
                        install_mysql
                    else
                        log_error "请手动处理MySQL服务后重试"
                        exit 1
                    fi
                else
                    log_info "MySQL服务启动成功"
                fi
            else
                log_error "请先启动MySQL服务后重试"
                exit 1
            fi
        else
            # MySQL服务已运行，获取密码
            echo ""
            read -rp "请输入MySQL root密码: " MYSQL_ROOT_PASS
            if [ -z "$MYSQL_ROOT_PASS" ]; then
                log_error "MySQL root密码不能为空"
                exit 1
            fi
        fi
    fi
}

# ==================== 配置数据库 ====================
setup_database() {
    log_step "4. 配置数据库"

    # 测试数据库连接
    log_info "测试数据库连接"
    if ! mysql -uroot -p"${MYSQL_ROOT_PASS}" -e "SELECT 1" &>/dev/null; then
        log_error "数据库连接失败，请检查root密码是否正确"
        exit 1
    fi
    log_info "数据库连接成功"

    # 设置Zabbix数据库密码
    echo ""
    read -rp "请设置Zabbix数据库密码 (回车默认使用 ${ZABBIX_DB_PASS}): " input_pass
    ZABBIX_DB_PASS="${input_pass:-$ZABBIX_DB_PASS}"

    # 创建数据库和用户
    log_info "创建Zabbix数据库和用户"
    mysql -uroot -p"${MYSQL_ROOT_PASS}" <<EOF
CREATE DATABASE IF NOT EXISTS ${ZABBIX_DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
CREATE USER IF NOT EXISTS '${ZABBIX_DB_USER}'@'%' IDENTIFIED BY '${ZABBIX_DB_PASS}';
GRANT ALL PRIVILEGES ON ${ZABBIX_DB_NAME}.* TO '${ZABBIX_DB_USER}'@'%';
SET GLOBAL log_bin_trust_function_creators = 1;
FLUSH PRIVILEGES;
EOF

    check_result "创建Zabbix数据库和用户"

    # 导入初始数据
    log_info "导入Zabbix初始数据"
    if [ -f /usr/share/zabbix-sql-scripts/mysql/server.sql.gz ]; then
        zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql --default-character-set=utf8mb4 -u"${ZABBIX_DB_USER}" -p"${ZABBIX_DB_PASS}" "${ZABBIX_DB_NAME}"
        check_result "导入Zabbix初始数据"
    else
        log_error "未找到Zabbix SQL数据文件"
        exit 1
    fi

    # 关闭log_bin_trust_function_creators
    mysql -uroot -p"${MYSQL_ROOT_PASS}" -e "SET GLOBAL log_bin_trust_function_creators = 0;"
    log_info "数据库配置完成"
}

# ==================== 安装和配置PHP ====================
setup_php() {
    log_step "5. 安装和配置PHP"

    # ==================== PHP 源配置（二选一） ====================
    # 使用方式: 在上方配置区域选择 USE_PHP_OFFICIAL 或 USE_PHP_NEXUS

    if [ "$USE_PHP_NEXUS" == "true" ]; then
        # ---------- Nexus 私有源 ----------
        log_info "使用 Nexus 私有源: ${NEXUS_URL}"

        # 导入 PHP PPA 签名密钥（从 Launchpad 下载）
        log_info "导入 PHP PPA 签名密钥"
        rm -f /usr/share/keyrings/nexus-php.gpg 2>/dev/null
        gpg --keyserver keyserver.ubuntu.com --recv-keys 4F4EA0AAE5267A6C 2>/dev/null
        gpg --export 4F4EA0AAE5267A6C | gpg --dearmor -o /usr/share/keyrings/nexus-php.gpg

        # 创建源文件
        log_info "创建 PHP 源文件"
        cat > /etc/apt/sources.list.d/php.list <<EOF
deb [trusted=yes] ${NEXUS_URL}/repository/php-apt/ $(lsb_release -cs) main
EOF

        apt update -qq

    elif [ "$USE_PHP_OFFICIAL" == "true" ]; then
        # ---------- 官方 PPA 源 ----------
        log_info "使用 PHP 官方 PPA 源"
        apt install -y software-properties-common
        add-apt-repository -y ppa:ondrej/php
        apt update -qq

    else
        log_error "未选择 PHP 源类型，请在脚本配置区域设置 USE_PHP_OFFICIAL 或 USE_PHP_NEXUS"
        exit 1
    fi

    # 安装PHP-FPM及Zabbix所需扩展
    log_info "安装PHP扩展"
    apt install -y \
        php${PHP_VERSION}-fpm \
        php${PHP_VERSION}-mysql \
        php${PHP_VERSION}-bcmath \
        php${PHP_VERSION}-mbstring \
        php${PHP_VERSION}-gd \
        php${PHP_VERSION}-xml \
        php${PHP_VERSION}-intl \
        php${PHP_VERSION}-soap \
        php${PHP_VERSION}-ldap \
        php${PHP_VERSION}-curl \
        php${PHP_VERSION}-zip

    # 安装语言包（Zabbix Web需要en_US.UTF-8，中文用户可选zh_CN.UTF-8）
    log_info "安装语言包"
    apt install -y locales
    locale-gen en_US.UTF-8 zh_CN.UTF-8
    update-locale LANG=zh_CN.UTF-8

    # 修改PHP配置
    local php_ini="/etc/php/${PHP_VERSION}/fpm/php.ini"
    if [ -f "$php_ini" ]; then
        log_info "修改PHP-FPM配置"
        cp "${php_ini}" "${php_ini}.bak"

        sed -i 's/post_max_size = .*/post_max_size = 16M/' "$php_ini"
        sed -i 's/max_execution_time = .*/max_execution_time = 300/' "$php_ini"
        sed -i 's/max_input_time = .*/max_input_time = 300/' "$php_ini"

        # 重启PHP-FPM
        systemctl restart "php${PHP_VERSION}-fpm"
        check_result "重启PHP-FPM"
    fi

    log_info "PHP配置完成"
}

# ==================== 配置Zabbix Server ====================
configure_zabbix_server() {
    log_step "6. 配置Zabbix Server"

    local zabbix_conf="/etc/zabbix/zabbix_server.conf"
    if [ ! -f "$zabbix_conf" ]; then
        log_error "未找到Zabbix Server配置文件"
        exit 1
    fi

    cp "${zabbix_conf}" "${zabbix_conf}.bak"

    # 配置数据库连接
    log_info "配置数据库连接"
    sed -i "s/#\s*DBPassword=.*/DBPassword=${ZABBIX_DB_PASS}/" "$zabbix_conf"
    sed -i "s/#\s*DBHost=.*/DBHost=${ZABBIX_SERVER_HOST}/" "$zabbix_conf"

    # 验证配置
    log_info "验证Zabbix Server配置"
    grep "^DB" "$zabbix_conf"

    log_info "Zabbix Server配置完成"
}

# ==================== 配置中文字体 ====================
setup_font() {
    log_step "7. 配置中文字体"

    local font_dir="/usr/share/fonts/truetype/dejavu"
    local font_file="${font_dir}/DejaVuSans.ttf"
    local font_url="https://script.huangjingblog.cn/system_init/msyh.ttc"

    # 备份原始字体
    if [ -f "$font_file" ] && [ ! -f "${font_file}.bak" ]; then
        cp "$font_file" "${font_file}.bak"
    fi

    # 下载微软雅黑字体
    log_info "下载中文字体"
    wget -q "$font_url" -O /tmp/msyh.ttc || {
        log_warn "下载中文字体失败，图表中文可能显示异常"
        log_info "下载地址: ${font_url}"
        return 0
    }

    # 替换Zabbix默认字体
    log_info "替换Zabbix字体"
    cp /tmp/msyh.ttc "$font_file"
    rm -f /tmp/msyh.ttc

    # 刷新字体缓存
    fc-cache -f 2>/dev/null

    log_info "中文字体配置完成"
}

# ==================== 配置Nginx ====================
configure_nginx() {
    log_step "8. 配置Nginx"

    local nginx_conf="/etc/nginx/conf.d/zabbix.conf"

    log_info "创建Nginx虚拟主机配置"
    cat > "$nginx_conf" <<EOF
server {
    listen          ${ZABBIX_SERVER_PORT};
    server_name     ${ZABBIX_DOMAIN};

    root            /usr/share/zabbix;
    index           index.php;

    location = /favicon.ico {
        log_not_found   off;
        access_log      off;
    }

    location ~ \.php\$ {
        fastcgi_pass    unix:/run/php/php${PHP_VERSION}-fpm.sock;
        fastcgi_index   index.php;
        fastcgi_param   SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include         fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

    # 删除默认站点配置（如果存在）
    if [ -f /etc/nginx/sites-enabled/default ]; then
        rm -f /etc/nginx/sites-enabled/default
    fi

    # 测试Nginx配置
    nginx -t
    check_result "测试Nginx配置"

    log_info "Nginx配置完成"
}

# ==================== 启动服务 ====================
start_services() {
    log_step "9. 启动服务"

    log_info "启动Zabbix Server"
    systemctl start zabbix-server
    check_result "启动Zabbix Server"

    log_info "启动Zabbix Agent2"
    systemctl start zabbix-agent2
    check_result "启动Zabbix Agent2"

    log_info "启动Nginx"
    systemctl start nginx
    check_result "启动Nginx"

    log_info "启动PHP-FPM"
    systemctl start "php${PHP_VERSION}-fpm"
    check_result "启动PHP-FPM"

    log_info "服务启动完成"
}

# ==================== 配置开机自启 ====================
enable_services() {
    log_step "10. 配置开机自启"

    systemctl enable zabbix-server zabbix-agent2 nginx
    systemctl enable "php${PHP_VERSION}-fpm"

    log_info "开机自启配置完成"
}

# ==================== 安装Zabbix ====================
do_install() {
    log_step "开始安装Zabbix ${ZABBIX_VERSION}"

    # 检查是否已安装
    if check_zabbix_installed; then
        read -rp "检测到Zabbix已安装，是否覆盖安装？(Y/n): " confirm
        if [[ "${confirm}" == "n" || "${confirm}" == "N" ]]; then
            log_info "取消安装"
            return 0
        fi
    fi

    # 配置访问域名
    setup_domain

    # 执行安装步骤
    setup_zabbix_repo
    ensure_mysql
    install_zabbix_packages
    setup_database
    setup_php
    configure_zabbix_server
    setup_font
    configure_nginx
    start_services
    enable_services

    echo ""
    echo -e "${CYAN}================================================================${RESET}"
    echo -e "${GREEN}          Zabbix ${ZABBIX_VERSION} 安装完成！${RESET}"
    echo -e "${CYAN}================================================================${RESET}"
    echo ""
    echo -e "  ${CYAN}访问地址:${RESET} http://${ZABBIX_DOMAIN}/"
    echo -e "  ${CYAN}默认账号:${RESET} ${GREEN}Admin${RESET}"
    echo -e "  ${CYAN}默认密码:${RESET} ${GREEN}zabbix${RESET}"
    echo ""
    echo -e "  ${CYAN}数据库地址:${RESET} ${ZABBIX_SERVER_HOST}"
    echo -e "  ${CYAN}数据库名称:${RESET} ${ZABBIX_DB_NAME}"
    echo -e "  ${CYAN}数据库用户:${RESET} ${ZABBIX_DB_USER}"
    echo -e "  ${CYAN}数据库密码:${RESET} ${YELLOW}${ZABBIX_DB_PASS}${RESET}"
    echo ""
    echo -e "  ${YELLOW}提示: 如果使用域名访问，请确保域名已解析到本机IP${RESET}"
    echo ""
}

# ==================== 卸载Zabbix ====================
do_uninstall() {
    log_step "开始卸载Zabbix"

    # 检查是否已安装
    if ! check_zabbix_installed; then
        log_warn "Zabbix未安装，无需卸载"
        return 0
    fi

    read -rp "确认卸载Zabbix？(Y/n): " confirm
    if [[ "${confirm}" == "n" || "${confirm}" == "N" ]]; then
        log_info "取消卸载"
        return 0
    fi

    # 停止服务
    log_info "停止Zabbix服务"
    systemctl stop zabbix-server zabbix-agent2 nginx 2>/dev/null
    systemctl stop "php${PHP_VERSION}-fpm" 2>/dev/null

    # 卸载Zabbix软件包
    log_info "卸载Zabbix软件包"
    apt purge -y zabbix-server-mysql zabbix-sql-scripts zabbix-frontend-php zabbix-agent2 2>/dev/null

    # 卸载Nginx
    echo ""
    read -rp "是否卸载Nginx？(Y/n): " del_nginx
    if [[ "${del_nginx}" != "n" && "${del_nginx}" != "N" ]]; then
        log_info "卸载Nginx"
        systemctl stop nginx 2>/dev/null
        systemctl disable nginx 2>/dev/null
        apt purge -y nginx nginx-common nginx-core 2>/dev/null
        apt autoremove -y 2>/dev/null
        # 清理残留
        rm -rf /etc/nginx /var/log/nginx
        systemctl daemon-reload 2>/dev/null
        log_info "Nginx卸载完成"
    fi

    # 卸载PHP
    echo ""
    read -rp "是否卸载PHP？(Y/n): " del_php
    if [[ "${del_php}" != "n" && "${del_php}" != "N" ]]; then
        log_info "卸载PHP"
        apt purge -y \
            php${PHP_VERSION}-fpm \
            php${PHP_VERSION}-mysql \
            php${PHP_VERSION}-bcmath \
            php${PHP_VERSION}-mbstring \
            php${PHP_VERSION}-gd \
            php${PHP_VERSION}-xml \
            php${PHP_VERSION}-intl \
            php${PHP_VERSION}-soap \
            php${PHP_VERSION}-ldap \
            php${PHP_VERSION}-curl \
            php${PHP_VERSION}-zip \
            php${PHP_VERSION}-common \
            php${PHP_VERSION}-cli 2>/dev/null
        apt autoremove -y 2>/dev/null
        log_info "PHP卸载完成"
    fi

    # 删除Zabbix配置文件
    log_info "删除Zabbix配置文件"
    rm -rf /etc/zabbix
    rm -f /etc/nginx/conf.d/zabbix.conf

    # 删除Zabbix数据目录
    log_info "删除Zabbix数据"
    rm -rf /var/lib/zabbix
    rm -rf /var/log/zabbix

    # 禁用服务
    systemctl disable zabbix-server zabbix-agent2 2>/dev/null

    # 删除Zabbix源配置
    echo ""
    read -rp "是否删除Zabbix源配置？(Y/n): " del_repo
    if [[ "${del_repo}" != "n" && "${del_repo}" != "N" ]]; then
        log_info "删除Zabbix源配置"
        rm -f /etc/apt/sources.list.d/zabbix.list
        apt update -qq 2>/dev/null
        log_info "Zabbix源配置已删除"
    fi

    # 询问是否删除数据库
    echo ""
    read -rp "是否删除Zabbix数据库？(Y/n): " del_db
    if [[ "${del_db}" != "n" && "${del_db}" != "N" ]]; then
        read -rp "请输入MySQL root密码: " del_root_pass
        mysql -uroot -p"${del_root_pass}" -e "DROP DATABASE IF EXISTS ${ZABBIX_DB_NAME}; DROP USER IF EXISTS '${ZABBIX_DB_USER}'@'%'; FLUSH PRIVILEGES;" 2>/dev/null
        log_info "Zabbix数据库已删除"
    fi

    # 询问是否卸载MySQL
    echo ""
    read -rp "是否卸载MySQL？(Y/n): " del_mysql
    if [[ "${del_mysql}" != "n" && "${del_mysql}" != "N" ]]; then
        log_info "卸载MySQL"

        # 停止MySQL服务
        systemctl stop mysql 2>/dev/null
        systemctl disable mysql 2>/dev/null

        # 使用包管理器完全卸载MySQL（purge清除配置和服务文件）
        apt purge -y mysql-server mysql-server-* mysql-client mysql-client-* mysql-common 2>/dev/null
        apt autoremove -y 2>/dev/null
        # 删除MySQL APT配置和源
        rm -f /etc/apt/sources.list.d/mysql.list 2>/dev/null
        apt update -qq 2>/dev/null

        # 清理残留的systemd服务文件
        rm -f /etc/systemd/system/multi-user.target.wants/mysql.service 2>/dev/null
        rm -f /lib/systemd/system/mysql.service 2>/dev/null
        systemctl daemon-reload 2>/dev/null

        # 删除配置文件
        rm -rf /var/lib/mysql
        rm -rf /var/log/mysql*

        log_info "MySQL卸载完成"
    fi

    log_info "${GREEN}Zabbix卸载完成${RESET}"
}

# ==================== 显示帮助 ====================
show_help() {
    echo -e "${CYAN}用法:${RESET} $0 [选项]"
    echo ""
    echo -e "${CYAN}说明:${RESET} 不传参数时默认执行install"
    echo ""
    echo -e "${CYAN}选项:${RESET}"
    echo "  install    安装Zabbix监控系统"
    echo "  uninstall  卸载Zabbix监控系统"
    echo "  -h,--help  显示此帮助信息"
    echo ""
    echo -e "${CYAN}示例:${RESET}"
    echo "  sudo $0          # 默认安装"
    echo "  sudo $0 install"
    echo "  sudo $0 uninstall"
    echo ""
    echo -e "${CYAN}组件说明:${RESET}"
    echo "  zabbix-server     Zabbix服务端"
    echo "  zabbix-agent2     Zabbix代理端"
    echo "  nginx             Web服务器"
    echo "  php               PHP环境"
    echo "  MySQL             数据库（可自动安装或手动安装）"
}

# ==================== 主函数 ====================
main() {
    echo -e "${CYAN}================================================================${RESET}"
    echo -e "${CYAN}          Zabbix ${ZABBIX_VERSION} 安装与卸载工具${RESET}"
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