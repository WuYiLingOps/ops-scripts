#!/bin/bash
#
#********************************************************************
#Author:           YiLing Wu (hj)
#email:            huangjing510@126.com
#Date:             2026-06-24
#FileName:         install-mysql-interactive.sh
#URL:              https://script.huangjingblog.cn
#Description:      MySQL交互式安装脚本，支持离线/在线安装，适配MySQL 5/8/9版本
#Copyright (C):    2024 All rights reserved
#********************************************************************

# 官网下载：https://downloads.mysql.com/archives/community/

source /etc/profile

# 全局配置
INSTALL_DIR="/data/mysql"
LINK_DIR="${INSTALL_DIR}/mysql"
WORK_DIR="/usr/local/src/mysql${MYSQL_VER}"
INTERNAL_MYSQL_BASE_URL="http://mirrors.xxx.cn/source/mysql/bin"
EXTERNAL_MYSQL_BASE_URL="https://cdn.mysql.com/archives/mysql-${MYSQL_VER%.*}"
OLD_MYSQL_VER=$(mysqld --version 2>/dev/null | awk '{print $3}')


# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 扫描当前目录下的 MySQL 安装包
# 功能：扫描脚本所在目录下的MySQL安装包（tar.gz和tar.xz格式）
# 参数：无
# 返回值：输出安装包数量和文件名列表（第一行为数量，后续行为文件名）
scan_local_packages() {
    local packages=()
    # 查找 tar.gz 和 tar.xz 文件
    while IFS= read -r -d '' file; do
        packages+=("$file")
    done < <(find "$SCRIPT_DIR" -maxdepth 1 -type f \( -name "mysql-*.tar.gz" -o -name "mysql-*.tar.xz" \) -print0 2>/dev/null)

    echo "${#packages[@]}"
    for pkg in "${packages[@]}"; do
        basename "$pkg"
    done
}

# 解析安装包信息
# 功能：从MySQL安装包文件名中提取版本号、架构、glibc版本等信息
# 参数：$1 - 安装包文件名（如 mysql-8.0.11-linux-glibc2.12-x86_64.tar.gz）
# 返回值：成功返回0并设置全局变量（MYSQL_VER、GLIBC_VER、ARCH等），失败返回1
parse_package_info() {
    local package_name="$1"
    # 从文件名中提取版本号和架构信息
    # 格式: mysql-VERSION-linux-glibc2.X-ARCH.tar.gz 或 .tar.xz
    if [[ "$package_name" =~ mysql-([0-9]+\.[0-9]+\.[0-9]+)-linux-glibc2\.([0-9]+)-([a-z0-9_]+)\.(tar\.gz|tar\.xz) ]]; then
        MYSQL_VER="${BASH_REMATCH[1]}"
        GLIBC_VER="${BASH_REMATCH[2]}"
        ARCH="${BASH_REMATCH[3]}"
        SUFFIX="${BASH_REMATCH[4]}"

        # 确定 MySQL 大版本
        if [[ "$MYSQL_VER" =~ ^5\. ]]; then
            MYSQL_NUM=1
        elif [[ "$MYSQL_VER" =~ ^8\. ]]; then
            MYSQL_NUM=2
        elif [[ "$MYSQL_VER" =~ ^9\. ]]; then
            MYSQL_NUM=3
        fi

        MYSQL_BASENAME="mysql-${MYSQL_VER}-linux-glibc2.${GLIBC_VER}-${ARCH}"
        MYSQL_SOURCE="${MYSQL_BASENAME}.${SUFFIX}"
        return 0
    fi
    return 1
}

# 检查是否有本地安装包
LOCAL_PACKAGES=($(scan_local_packages))
LOCAL_PACKAGE_COUNT=${LOCAL_PACKAGES[0]}
# 移除第一个元素（计数），保留实际包名
unset LOCAL_PACKAGES[0]
LOCAL_PACKAGES=("${LOCAL_PACKAGES[@]}")

# 初始化变量
LOCAL_PACKAGE_FOUND=""
INSTALL_MODE=""

# 第一步：选择安装方式
if [ "$LOCAL_PACKAGE_COUNT" -gt 0 ]; then
    clear
    echo -e "———————————————————————————
\033[32mMySQL 安装方式选择\033[0m
———————————————————————————"
    echo -e "\033[33m检测到当前目录下有 ${LOCAL_PACKAGE_COUNT} 个 MySQL 安装包：\033[0m"
    for i in "${!LOCAL_PACKAGES[@]}"; do
        echo -e "  $((i+1)). ${LOCAL_PACKAGES[$i]}"
    done
    echo
    echo -e "1. 使用本地安装包（离线安装）"
    echo -e "2. 在线下载安装（在线安装）\n"

    read -rp "请选择编号(默认为 1)：" INSTALL_MODE_NUM
    [ -z "$INSTALL_MODE_NUM" ] && INSTALL_MODE_NUM=1

    if [ "$INSTALL_MODE_NUM" -eq 1 ]; then
        INSTALL_MODE="local"
        if [ "$LOCAL_PACKAGE_COUNT" -eq 1 ]; then
            # 只有一个包，直接使用
            LOCAL_PACKAGE_FOUND="$SCRIPT_DIR/${LOCAL_PACKAGES[0]}"
            parse_package_info "${LOCAL_PACKAGES[0]}"
        else
            # 多个包，让用户选择
            echo -e "\n请选择要使用的安装包编号："
            read -rp "请输入编号(默认为 1)：" PKG_NUM
            [ -z "$PKG_NUM" ] && PKG_NUM=1
            LOCAL_PACKAGE_FOUND="$SCRIPT_DIR/${LOCAL_PACKAGES[$((PKG_NUM-1))]}"
            parse_package_info "${LOCAL_PACKAGES[$((PKG_NUM-1))]}"
        fi
    else
        INSTALL_MODE="online"
    fi
else
    INSTALL_MODE="online"
fi

# 离线安装模式下直接开始安装（变量传递给后面的函数）
if [ "$INSTALL_MODE" == "local" ]; then
    AUTO_INSTALL="local"
fi

# 第二步：如果选择在线安装，让用户选择版本
if [ "$INSTALL_MODE" == "online" ]; then
    while true; do
        clear
        echo -e "——————————————
\033[32mMySQL安装版本\033[0m
——————————————
1. MySQL 5
2. MySQL 8
3. MySQL 9
"
        read -rp "请选择编号(默认为 2)：" MYSQL_NUM
        [ -z "$MYSQL_NUM" ] && MYSQL_NUM=2

        if [ $MYSQL_NUM -eq 1 ]; then
            read -rp "请输入安装 MySQL 的版本号(默认为 5.7.44)：" MYSQL_VER
            [ -z "$MYSQL_VER" ] && MYSQL_VER="5.7.44"
            GLIBC_VER=12
            break
        elif [ $MYSQL_NUM -eq 2 ]; then
            read -rp "请输入安装 MySQL 的版本号(默认为 8.0.44)：" MYSQL_VER
            [ -z "$MYSQL_VER" ] && MYSQL_VER="8.0.44"
            if [[ "$(printf '%s\n' "$MYSQL_VER" "8.0.33" | sort -V | head -n1)" == "$MYSQL_VER" ]]; then
                GLIBC_VER=12
            else
                GLIBC_VER=17
            fi
            break
        elif [ $MYSQL_NUM -eq 3 ]; then
            read -rp "请输入安装 MySQL 的版本号(默认为 9.5.0)：" MYSQL_VER
            [ -z "$MYSQL_VER" ] && MYSQL_VER="9.5.0"
            GLIBC_VER=17
            break
        fi
    done

    # 构建安装包文件名
    ARCH=$(uname -m)
    MYSQL_BASENAME="mysql-${MYSQL_VER}-linux-glibc2.${GLIBC_VER}-${ARCH}"
fi

# 输出信息日志
# 功能：输出带时间戳的信息级别日志
echo_log_info() {
    echo -e "$(date +'%F %T') - [Info] $*"
}

# 输出警告日志
# 功能：输出带时间戳的警告级别日志
echo_log_warn() {
    echo -e "$(date +'%F %T') - [Warn] $*"
}

# 输出错误日志并退出
# 功能：输出带时间戳的错误级别日志，然后退出脚本
# 注意：此函数会调用exit 1终止脚本执行
echo_log_error() {
    echo -e "$(date +'%F %T') - [Error] $*"
    exit 1
}

# 检查URL是否可用
# 功能：检查MySQL安装包在指定URL是否存在且可访问
# 参数：$1 - 基础URL路径
# 返回值：如果URL可用返回0，否则返回1
check_url() {
    for suffix in tar.gz tar.xz; do
        MYSQL_SOURCE="${MYSQL_BASENAME}.${suffix}"
        MYSQL_URL="$1/${MYSQL_SOURCE}"

        if curl --head --silent --fail --connect-timeout 5 "$MYSQL_URL" > /dev/null; then
            return 0
        fi
    done

    return 1
}

# RPM包管理器依赖检查和安装
# 功能：检查并安装RPM包管理器系统（如CentOS/RHEL）所需的依赖包
# 参数：$@ - 需要检查和安装的依赖包列表
# 返回值：所有依赖安装成功返回0，否则返回1
depend_judge_rpm() {
    rpm -q $@ &>/dev/null && return || echo_log_info "安装依赖"
    for arg in $@; do
        if [[ "$arg" == "gcc" ]]; then
            which $arg &>/dev/null || yum install -y $arg &>/dev/null
        elif [[ "$arg" == "gcc-c++" ]]; then
            which g++ &>/dev/null || yum install -y $arg &>/dev/null
        else
            rpm -q $arg &>/dev/null || yum install -y $arg &>/dev/null
        fi
        [ $? -ne 0 ] && return 1
    done
    return 0
}

# DPKG包管理器依赖检查和安装
# 功能：检查并安装DPKG包管理器系统（如Ubuntu/Debian）所需的依赖包
# 参数：$@ - 需要检查和安装的依赖包列表
# 返回值：所有依赖安装成功返回0，否则返回1
depend_judge_dpkg() {
    dpkg -s $@ &>/dev/null && return || echo_log_info "安装依赖"
    apt update -qq &>/dev/null
    for arg in $@; do
        if [[ "$arg" =~ (gcc|g\+\+) ]]; then
            which $arg &>/dev/null || apt install -y $arg &>/dev/null
        else
            dpkg -s $arg &>/dev/null || apt install -y $arg &>/dev/null
        fi
        [ $? -ne 0 ] && return 1
    done
    return 0
}

# 关闭防火墙和SELinux
# 功能：根据操作系统类型关闭防火墙和SELinux，避免安装过程被拦截
# 注意：支持CentOS/RHEL系列（firewalld+SELinux）和Ubuntu/Debian系列（ufw）
close_fw() {
    . /etc/os-release
    if [[ ! "$ID" =~ (debian|ubuntu) ]]; then
        if firewall-cmd --state &>/dev/null; then
            echo_log_info "关闭防火墙"
            systemctl stop firewalld && systemctl disable firewalld &>/dev/null
        fi
        if ! grep -q 'SELINUX=disabled' /etc/selinux/config; then
            echo_log_info "关闭selinux"
            sed -i 's/enforcing/disabled/' /etc/selinux/config
            setenforce 0 &>/dev/null
        fi
    else
        if command -v ufw &>/dev/null && ufw status | grep -q "active"; then
            echo_log_info "关闭防火墙"
            ufw disable &>/dev/null
        fi
    fi
}

# 主菜单函数
# 功能：显示MySQL安装工具的主菜单，提供安装、重置密码、卸载和退出选项
# 注意：根据用户选择调用相应的功能函数
main() {
    clear
    echo -e "———————————————————————————
\033[32m MySQL${MYSQL_VER} 安装工具\033[0m
———————————————————————————"

    # 显示安装模式
    if [ "$INSTALL_MODE" == "local" ]; then
        echo -e "\033[33m安装模式: 离线安装（使用本地安装包）\033[0m"
        echo -e "\033[33m安装包: $(basename "$LOCAL_PACKAGE_FOUND")\033[0m"
    else
        echo -e "\033[33m安装模式: 在线安装\033[0m"
    fi
    echo

    echo -e "1. 安装MySQL${MYSQL_VER}
2. 重置MySQL root密码
3. 卸载MySQL${MYSQL_VER}
4. 退出\n"

    read -rp "请输入序号并回车：" num
    case "$num" in
    1) (install_mysql) ;;
    2) (resetpwd_root) ;;
    3) (remove_mysql) ;;
    4) (quit) ;;
    *) (main) ;;
    esac
}

# 安装MySQL函数
# 功能：执行MySQL的完整安装流程，包括下载/解压、配置、初始化数据库、启动服务等
# 注意：支持离线安装（本地安装包）和在线安装两种模式
install_mysql() {
    if [[ "$OLD_MYSQL_VER" == "$MYSQL_VER" ]] || [ -d "$INSTALL_DIR/$MYSQL_BASENAME" ]; then
        [ -d "$INSTALL_DIR/$MYSQL_BASENAME" ] && MYSQL_DIR="$INSTALL_DIR/$MYSQL_BASENAME" || MYSQL_DIR="${LINK_DIR%/mysql}/$(readlink $LINK_DIR)"
        echo_log_warn "系统中已安装源码 \033[33mmysql${MYSQL_VER}\033[0m ,安装目录为 \033[33m$MYSQL_DIR\033[0m"
        if [ ! -e "$LINK_DIR" ]; then
            echo_log_warn "系统未配置安装目录的软链接,开始配置"
            cd ${LINK_DIR%/mysql} && ln -sf $MYSQL_BASENAME mysql
            flag=1
        elif [[ "$(readlink $LINK_DIR)" != "$MYSQL_BASENAME" ]]; then
            echo_log_warn "系统已配置 \033[33mmysql${OLD_MYSQL_VER}\033[0m 版本目录的软链接,重新生成新的软链接"
            cd ${LINK_DIR%/mysql} && rm -f mysql && ln -sf $MYSQL_BASENAME mysql
            flag=1
        fi
        if [ ! -f /etc/ld.so.conf.d/mysql.conf ]; then
            echo_log_warn "系统中未配置动态链接库,开始配置"
            echo "$LINK_DIR/lib" > /etc/ld.so.conf.d/mysql.conf && ldconfig
        else
            ldconfig
        fi
        if [ ! -f /etc/profile.d/mysql.sh ]; then
            echo_log_warn "系统中未配置环境变量,开始配置"
            cat > /etc/profile.d/mysql.sh <<EOF
# MySQL
export MYSQL_HOME=${LINK_DIR}
export PATH=\$MYSQL_HOME/bin:\$MYSQL_HOME/lib:\$PATH
export PKG_CONFIG_PATH=\$MYSQL_HOME/lib/pkgconfig:\$PKG_CONFIG_PATH
EOF
            source /etc/profile
        fi
        if [ ! -f /etc/my.cnf ]; then
            echo_log_warn "系统中未创建配置文件,开始创建"
            cat > /etc/my.cnf <<EOF
[mysqld]
port = 3306
user = mysql
bind-address = 0.0.0.0

datadir = $LINK_DIR/data
plugin-dir = $LINK_DIR/lib/plugin
socket = /tmp/mysql.sock
pid-file = $LINK_DIR/mysqld.pid
log-error = $LINK_DIR/log/mysqld.log

skip-log-bin

character-set-server = utf8mb4
collation-server = utf8mb4_general_ci
init-connect = 'SET NAMES utf8mb4'
sql_mode = "STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION"
skip-name-resolve
mysqlx = 0

max_connections = 2000
performance_schema = OFF
lower_case_table_names = 1
authentication_policy = mysql_native_password
explicit_defaults_for_timestamp = 1

[client]
socket = /tmp/mysql.sock
EOF
            if [ $MYSQL_NUM -eq 1 ]; then
                sed -i '/^authentication_policy/d' /etc/my.cnf
                sed -i '/^mysqlx/d' /etc/my.cnf
            elif [ $MYSQL_NUM -eq 2 ] && [[ "${MYSQL_VER%.*}" == "8.4" ]]; then
                sed -i '/^authentication_policy/c mysql_native_password = ON' /etc/my.cnf
            elif [ $MYSQL_NUM -eq 3 ]; then
                sed -i '/^authentication_policy/d' /etc/my.cnf
            fi
        elif [ $MYSQL_NUM -eq 1 ]; then
            if grep -qE 'mysql_native_password|mysqlx' /etc/my.cnf; then
                echo_log_warn "系统已配置 \033[33mmysql${OLD_MYSQL_VER}\033[0m 版本的配置文件,重新配置"
                sed -i '/mysql_native_password/d' /etc/my.cnf
                sed -i '/^mysqlx/d' /etc/my.cnf
            fi
        elif [ $MYSQL_NUM -eq 2 ]; then
            if [[ "$(printf '%s\n' "$MYSQL_VER" "8.0.26" | sort -V | head -n1)" == "$MYSQL_VER" ]] && 
            ( ! grep -q '^default_authentication_plugin' /etc/my.cnf || ! grep -q '^mysqlx' /etc/my.cnf || 
                grep -q '^authentication_policy' /etc/my.cnf || grep -q '^mysql_native_password' /etc/my.cnf ); then
                    echo_log_warn "系统已配置 \033[33mmysql${OLD_MYSQL_VER}\033[0m 版本的配置文件,重新配置"
                    ! grep -q '^default_authentication_plugin' /etc/my.cnf && sed -i '/lower_case_table_names/a default_authentication_plugin = mysql_native_password' /etc/my.cnf
                    ! grep -q '^mysqlx' /etc/my.cnf && sed -i '/^skip-name-resolve/a mysqlx = 0' /etc/my.cnf
                    grep -q '^authentication_policy' /etc/my.cnf && sed -i '/^authentication_policy/d' /etc/my.cnf
                    grep -q '^mysql_native_password' /etc/my.cnf && sed -i '/^mysql_native_password/d' /etc/my.cnf

            elif [[ "${MYSQL_VER%.*}" == "8.4" ]] && 
            ( grep -q '^default_authentication_plugin' /etc/my.cnf || ! grep -q '^mysqlx' /etc/my.cnf || 
                ! grep -q '^authentication_policy' /etc/my.cnf || ! grep -q '^mysql_native_password' /etc/my.cnf ); then
                    echo_log_warn "系统已配置 \033[33mmysql${OLD_MYSQL_VER}\033[0m 版本的配置文件,重新配置"
                    grep -q '^default_authentication_plugin' /etc/my.cnf && sed -i '/^default_authentication_plugin/d' /etc/my.cnf
                    ! grep -q '^mysqlx' /etc/my.cnf && sed -i '/^skip-name-resolve/a mysqlx = 0' /etc/my.cnf
                    ! grep -q '^authentication_policy' /etc/my.cnf && sed -i '/lower_case_table_names/a authentication_policy = mysql_native_password' /etc/my.cnf
                    ! grep -q '^mysql_native_password' /etc/my.cnf && sed -i '/lower_case_table_names/a mysql_native_password = ON' /etc/my.cnf

            elif [[ "${MYSQL_VER%.*}" != "8.4" ]] && 
            ( grep -q '^default_authentication_plugin' /etc/my.cnf || ! grep -q '^mysqlx' /etc/my.cnf || 
                ! grep -q '^authentication_policy' /etc/my.cnf || grep -q '^mysql_native_password' /etc/my.cnf ); then
                    echo_log_warn "系统已配置 \033[33mmysql${OLD_MYSQL_VER}\033[0m 版本的配置文件,重新配置"
                    grep -q '^default_authentication_plugin' /etc/my.cnf && sed -i '/^default_authentication_plugin/d' /etc/my.cnf
                    ! grep -q '^mysqlx' /etc/my.cnf && sed -i '/^skip-name-resolve/a mysqlx = 0' /etc/my.cnf
                    ! grep -q '^authentication_policy' /etc/my.cnf && sed -i '/lower_case_table_names/a authentication_policy = mysql_native_password' /etc/my.cnf
                    grep -q '^mysql_native_password' /etc/my.cnf && sed -i '/^mysql_native_password/d' /etc/my.cnf
            fi
        elif [ $MYSQL_NUM -eq 3 ]; then
            if grep -q 'mysql_native_password' /etc/my.cnf || ! grep -q '^mysqlx' /etc/my.cnf; then
                echo_log_warn "系统已配置 \033[33mmysql${OLD_MYSQL_VER}\033[0m 版本的配置文件,重新配置"
                sed -i '/mysql_native_password/d' /etc/my.cnf
                ! grep -q '^mysqlx' /etc/my.cnf && sed -i '/^skip-name-resolve/a mysqlx = 0' /etc/my.cnf
            fi
        fi
        if [ ! -f /usr/lib/systemd/system/mysqld.service ]; then
            echo_log_warn "系统中未配置服务,开始配置并启动"
            cat > /usr/lib/systemd/system/mysqld.service <<EOF
[Unit]
Description=MySQL Server
After=network.target

[Service]
Type=simple
User=mysql
Group=mysql
ExecStart=${LINK_DIR}/bin/mysqld --defaults-file=/etc/my.cnf
LimitNOFILE=65536
Restart=on-failure
RestartSec=5
StartLimitInterval=60
StartLimitBurst=3

[Install]
WantedBy=multi-user.target
EOF
            systemctl daemon-reload && systemctl start mysqld &>/dev/null
            [ $? -ne 0 ] && echo_log_error "\033[31m启动服务失败\033[0m"
        elif [[ "$flag" == "1" ]]; then
            echo_log_info "重启服务" && systemctl restart mysqld &>/dev/null
            [ $? -ne 0 ] && echo_log_error "\033[31m重启服务失败\033[0m"
        fi
        echo && exit 1
    fi

    read -rp "请输入需要设置MySQL的 root 密码 (回车默认使用随机密码) ：" mysql_root_password
    if [ -z "$mysql_root_password" ]; then
        mysql_root_password=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 8)
    fi

    echo && close_fw && . /etc/os-release

    echo_log_info "清理系统默认 mysql 和 mariadb "
    if command -v yum &>/dev/null; then
        rpm -qa | grep mysql | xargs rpm -e --nodeps &>/dev/null
        rpm -qa | grep mariadb | xargs rpm -e --nodeps &>/dev/null
    elif command -v apt &>/dev/null; then
        dpkg -l | grep mysql | awk '{print $2}' | xargs dpkg --purge --force-all &>/dev/null
        dpkg -l | grep mariadb | awk '{print $2}' | xargs dpkg --purge --force-all &>/dev/null
    fi
    
    if [[ "$ID" =~ (rhel|centos|almalinux|rocky) ]]; then
        [[ ${VERSION_ID%.*} -le 7 ]] && depend_judge_rpm wget libaio || depend_judge_rpm wget libaio ncurses-compat-libs
    elif [[ "$ID" =~ (openEuler|fedora) ]]; then
        depend_judge_rpm wget libaio ncurses-compat-libs
    elif [[ "$ID" =~ (debian|ubuntu) ]]; then
        depend_judge_dpkg wget libaio1 libncurses5 libnuma1
    fi
    [ $? -ne 0 ] && echo_log_error "\033[31m安装依赖失败，请检查网络连接\033[0m"

    echo_log_info "\033[32m开始安装 mysql ${MYSQL_VER}...\033[0m"

    [ -d $INSTALL_DIR ] || mkdir -p $INSTALL_DIR

    # 检查是否有本地安装包，直接解压到安装目录
    if [ -n "$LOCAL_PACKAGE_FOUND" ] && [ -f "$LOCAL_PACKAGE_FOUND" ]; then
        echo_log_info "使用本地安装包: $(basename "$LOCAL_PACKAGE_FOUND")"
        echo_log_info "正在解压文件 $(basename "$LOCAL_PACKAGE_FOUND")"
        tar -xzf "$LOCAL_PACKAGE_FOUND" -C $INSTALL_DIR &>/dev/null || tar -xJf "$LOCAL_PACKAGE_FOUND" -C $INSTALL_DIR &>/dev/null
    else
        [ ! -d "$WORK_DIR" ] && mkdir -p "$WORK_DIR"

        if [ ! -f "$WORK_DIR/$MYSQL_SOURCE" ]; then
            # 在线下载
            if check_url "$INTERNAL_MYSQL_BASE_URL"; then
                echo_log_info "从内部源下载源码bin包 $MYSQL_URL"
                wget -qP "$WORK_DIR" $MYSQL_URL &>/dev/null
            elif check_url "$EXTERNAL_MYSQL_BASE_URL"; then
                echo_log_info "从外部源下载源码bin包 $MYSQL_URL"
                wget -qP "$WORK_DIR" $MYSQL_URL &>/dev/null
            else
                echo_log_error "\033[31m下载源码bin包失败,请检查内部源或外部源下载地址是否正确\033[0m"
            fi
        else
            echo_log_info "使用已下载的安装包: $MYSQL_SOURCE"
        fi

        echo_log_info "正在解压文件 ${MYSQL_SOURCE}"
        tar -xzf "$WORK_DIR/$MYSQL_SOURCE" -C $INSTALL_DIR &>/dev/null || tar -xJf "$WORK_DIR/$MYSQL_SOURCE" -C $INSTALL_DIR &>/dev/null
    fi

    echo_log_info "创建软链接"
    cd $INSTALL_DIR && rm -f mysql && ln -sf $MYSQL_BASENAME mysql

    echo_log_info "创建日志目录" && mkdir $LINK_DIR/log

    if ! id "mysql" &>/dev/null; then
        echo_log_info "创建 mysql 用户" && useradd -r -s /sbin/nologin -M mysql
    fi

    echo_log_info "设置安装目录所有权为 \033[33mmysql\033[0m 用户" && chown -R mysql:mysql $INSTALL_DIR/$MYSQL_BASENAME

    echo_log_info "修改 pkf-config 文件" && sed -i "/prefix=/c prefix=$LINK_DIR" $LINK_DIR/lib/pkgconfig/mysqlclient.pc

    echo_log_info "配置动态链接库"
    echo "$LINK_DIR/lib" > /etc/ld.so.conf.d/mysql.conf && ldconfig

    echo_log_info "配置环境变量"
    cat > /etc/profile.d/mysql.sh <<EOF
# MySQL
export MYSQL_HOME=${LINK_DIR}
export PATH=\$MYSQL_HOME/bin:\$MYSQL_HOME/lib:\$PATH
export PKG_CONFIG_PATH=\$MYSQL_HOME/lib/pkgconfig:\$PKG_CONFIG_PATH
EOF
    source /etc/profile

    echo_log_info "创建配置文件"
    cat > /etc/my.cnf <<EOF
[mysqld]
port = 3306
user = mysql
bind-address = 0.0.0.0

datadir = $LINK_DIR/data
plugin-dir = $LINK_DIR/lib/plugin
socket = /tmp/mysql.sock
pid-file = $LINK_DIR/mysqld.pid
log-error = $LINK_DIR/log/mysqld.log

skip-log-bin

character-set-server = utf8mb4
collation-server = utf8mb4_general_ci
init-connect = 'SET NAMES utf8mb4'
sql_mode = "STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION"
skip-name-resolve
mysqlx = 0

max_connections = 2000
performance_schema = OFF
lower_case_table_names = 1
authentication_policy = mysql_native_password
explicit_defaults_for_timestamp = 1

[client]
socket = /tmp/mysql.sock
EOF
    if [ $MYSQL_NUM -eq 1 ]; then
        sed -i '/^authentication_policy/d' /etc/my.cnf
        sed -i '/^mysqlx/d' /etc/my.cnf
    elif [ $MYSQL_NUM -eq 2 ]; then
        if [[ "$(printf '%s\n' "$MYSQL_VER" "8.0.26" | sort -V | head -n1)" == "$MYSQL_VER" ]]; then
            sed -i '/^authentication_policy/c default_authentication_plugin = mysql_native_password' /etc/my.cnf
        elif [[ "${MYSQL_VER%.*}" == "8.4" ]]; then
            sed -i '/^authentication_policy/i mysql_native_password = ON' /etc/my.cnf
        fi
    elif [ $MYSQL_NUM -eq 3 ]; then
        sed -i '/^authentication_policy/d' /etc/my.cnf
    fi

    echo_log_info "初始化数据库"
    $LINK_DIR/bin/mysqld --initialize-insecure --user=mysql --basedir=$LINK_DIR --datadir=$LINK_DIR/data
    [ $? -ne 0 ] && echo_log_error "\033[31m初始化数据库失败\033[0m"

    if [ ! -f /usr/lib/systemd/system/mysqld.service ]; then
        echo_log_info "配置 systemd 服务"
        cat > /usr/lib/systemd/system/mysqld.service <<EOF
[Unit]
Description=MySQL Server
After=network.target

[Service]
Type=simple
User=mysql
Group=mysql
ExecStart=$LINK_DIR/bin/mysqld --defaults-file=/etc/my.cnf
LimitNOFILE=65536
Restart=on-failure
RestartSec=5
StartLimitInterval=60
StartLimitBurst=3

[Install]
WantedBy=multi-user.target
EOF
        echo_log_info "启动服务"
        systemctl daemon-reload && systemctl start mysqld &>/dev/null
        [ $? -ne 0 ] && echo_log_error "\033[31m启动服务失败\033[0m"
        systemctl enable mysqld &>/dev/null
    else
        echo_log_info "系统中存在源码安装的 mysql 服务配置文件,重启服务"
        systemctl restart mysqld &>/dev/null
        [ $? -ne 0 ] && echo_log_error "\033[31m重启服务失败\033[0m"
    fi
    
    sleep 3 && echo_log_info "设置 MySQL root 密码..."
    if [ $MYSQL_NUM -eq 1 ]; then
        mysql -uroot <<EOF
USE mysql;
ALTER user 'root'@'localhost' identified by '$mysql_root_password';
UPDATE user SET host='%' where user='root' and host='localhost';
FLUSH PRIVILEGES;
EOF
    else
        mysql -uroot <<EOF
USE mysql;
ALTER user 'root'@'localhost' identified by '$mysql_root_password';
UPDATE user SET host='%' where user='root' and host='localhost';
FLUSH PRIVILEGES;
GRANT SYSTEM_VARIABLES_ADMIN ON *.* TO 'root'@'%';
FLUSH PRIVILEGES;
EOF
    fi
    [ $? -eq 0 ] && echo_log_info "设置 MySQL root 密码 \033[33m${mysql_root_password}\033[0m 成功" || echo_log_error "\033[31m设置 MySQL root 密码失败,检查并再执行脚本,重置 root 密码\033[0m"
}

# 重置MySQL root密码函数
# 功能：重置MySQL root用户的密码，支持自定义密码或生成随机密码
# 注意：需要MySQL服务正在运行，通过skip-grant-tables模式临时绕过权限验证
resetpwd_root() {
    if [[ "$OLD_MYSQL_VER" != "$MYSQL_VER" ]] || [ ! -d "$INSTALL_DIR/$MYSQL_BASENAME" ]; then
        echo_log_warn "系统中未安装或配置源码 \033[33mmysql${MYSQL_VER}\033[0m\n" && exit 1
    fi

    read -rp "请输入需要设置MySQL的 root 密码 (回车默认使用随机密码) ：" mysql_root_password
    if [ -z "$mysql_root_password" ]; then
        mysql_root_password=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 8)
    fi

    echo && echo_log_info "重置 MySQL root 密码..."
    sed -i '/^\[client\]/i skip-grant-tables' /etc/my.cnf
    systemctl restart mysqld &>/dev/null && sleep 5

    $LINK_DIR/bin/mysql -uroot <<EOF
FLUSH PRIVILEGES;
ALTER user 'root'@'%' identified by '$mysql_root_password';
FLUSH PRIVILEGES;
EOF
    [ $? -eq 0 ] && echo_log_info "重置 MySQL root 密码 \033[33m${mysql_root_password}\033[0m 成功" || echo_log_error "\033[31m重置 MySQL root 密码失败\033[0m"

    sed -i '/skip-grant-tables/d' /etc/my.cnf
    systemctl restart mysqld &>/dev/null
}

# 卸载MySQL函数
# 功能：卸载指定版本的MySQL，包括停止服务、删除配置文件、清理安装目录等
# 注意：会删除MySQL的所有配置和数据，请谨慎操作
remove_mysql() {
    if [ ! -d "$INSTALL_DIR/$MYSQL_BASENAME" ]; then
        echo_log_warn "系统中已卸载源码 \033[33mmysql${MYSQL_VER}\033[0m\n"
        exit 1
    fi

    echo_log_info "\033[32m开始卸载 MYSQL ${MYSQL_VER}...\033[0m"

    if [[ "$OLD_MYSQL_VER" == "$MYSQL_VER" ]]; then
        echo_log_info "停止服务" && systemctl stop mysqld &>/dev/null
        [ $? -ne 0 ] && echo_log_error "\033[31m停止服务失败\033[0m"

        rm -rf /usr/lib/systemd/system/mysqld.service && systemctl daemon-reload && echo_log_info "删除 systemd 服务"
        rm -f /etc/ld.so.conf.d/mysql.conf && ldconfig && echo_log_info "删除动态链路库"
        rm -f /etc/profile.d/mysql.sh && source /etc/profile && echo_log_info "删除环境变量"
        rm -rf /etc/my.cnf && echo_log_info "删除配置文件"
    fi
    rm -rf $INSTALL_DIR/$MYSQL_BASENAME && echo_log_info "删除安装目录"
}

# 退出函数
# 功能：显示退出信息并终止脚本执行
quit() {
    echo_log_info "\033[33m退出安装工具\033[0m\n"
    exit 0
}

# 离线安装模式下直接开始安装
if [ "$AUTO_INSTALL" == "local" ]; then
    clear
    echo -e "———————————————————————————
\033[32m MySQL${MYSQL_VER} 安装工具\033[0m
———————————————————————————"
    echo -e "\033[33m安装模式: 离线安装\033[0m"
    echo -e "\033[33m检测到本地安装包: $(basename "$LOCAL_PACKAGE_FOUND")\033[0m"
    echo
fi

main