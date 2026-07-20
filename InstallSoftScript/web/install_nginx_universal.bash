#!/bin/bash
#
#********************************************************************
#Author:           YiLing Wu (hj)
#email:            huangjing510@126.com
#Date:             2026-05-02 17:58:03
#FileName:         install_nginx_universal.bash
#URL:              https://script.huangjingblog.cn
#Description:      通用 Nginx 编译安装脚本，支持 RedHat/CentOS/Rocky/Ubuntu/Debian 等主流系统
#Copyright (C):    2026 All rights reserved
#********************************************************************

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
    . /etc/os-release
    HOST=$(hostname -I|awk '{print $1}')
    if command -v apt &> /dev/null; then
        PKG_MANAGER="apt"
    elif command -v yum &> /dev/null; then
        PKG_MANAGER="yum"
    else
        color "未检测到支持的包管理器" 1
        exit 1
    fi
    color "系统: ${PRETTY_NAME}" 0
}

# 检查 root 权限
check_root() {
    if [ $EUID -ne 0 ]; then
        color "请使用 root 用户执行 (sudo ./xxx.sh)" 1
        exit 1
    fi
}

check_root

# 支持命令行参数传递版本号，默认 1.24.0
NGINX_VERSION="${1:-1.24.0}"
NGINX_PREFIX="/usr/local/nginx"
NGINX_TAR="nginx-${NGINX_VERSION}.tar.gz"
NGINX_SRC_DIR="/usr/local/src/nginx-${NGINX_VERSION}"

color "准备安装 Nginx 版本：${NGINX_VERSION}" 0

# 系统识别
echo "识别操作系统类型"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    color "检测到系统：$PRETTY_NAME" 0
elif [ -f /etc/redhat-release ]; then
    OS="centos"
    color "检测到系统：CentOS/RHEL" 0
else
    color "无法识别操作系统类型" 1
    exit 1
fi

# 安装依赖
echo "安装依赖包"
case $OS in
    ubuntu|debian)
        color "使用 apt-get 安装依赖" 0
        apt-get update -y
        apt-get install -y \
            build-essential \
            libpcre3 libpcre3-dev \
            zlib1g-dev \
            libssl-dev \
            libgd-dev libpng-dev libjpeg-dev libfreetype6-dev \
            wget curl
        if [ $? -ne 0 ]; then
            color "依赖安装失败" 1
            exit 1
        fi
        NOLOGIN_PATH="/usr/sbin/nologin"
        ;;
    centos|rhel|fedora|rocky|almalinux|amzn)
        color "使用 yum 安装依赖" 0
        yum install -y gcc gcc-c++ automake openssl openssl-devel make pcre-devel gd-devel wget curl
        if [ $? -ne 0 ]; then
            color "依赖安装失败" 1
            exit 1
        fi
        NOLOGIN_PATH="/sbin/nologin"
        ;;
    *)
        color "不支持的操作系统：$OS" 1
        exit 1
        ;;
esac

# 创建 nginx 用户
if id nginx >/dev/null 2>&1; then
    color "用户 nginx 已存在，跳过创建" 2
else
    echo "创建 nginx 用户"
    useradd -s $NOLOGIN_PATH -M nginx
    if [ $? -ne 0 ]; then
        color "创建 nginx 用户失败" 1
        exit 1
    fi
fi

# 创建日志目录
echo "创建日志目录"
mkdir -p /var/log/nginx
if [ $? -ne 0 ]; then
    color "创建日志目录失败" 1
    exit 1
fi

# 下载并解压源码
mkdir -p /usr/local/src
echo "准备 Nginx 源码包版本 ${NGINX_VERSION}"
if [ -f "${NGINX_TAR}" ]; then
    color "检测到本地源码包 ${NGINX_TAR}，跳过下载" 2
elif [ -f "/usr/local/src/${NGINX_TAR}" ]; then
    color "检测到本地源码包 /usr/local/src/${NGINX_TAR}，跳过下载" 2
else
    color "从官方下载 Nginx 源码" 0
    wget -P /usr/local/src "https://nginx.org/download/${NGINX_TAR}"
    if [ $? -ne 0 ]; then
        color "下载 Nginx 源码失败，请检查网络或版本号" 1
        exit 1
    fi
fi

echo "解压源码包到 /usr/local/src/"
tar -xzf "/usr/local/src/${NGINX_TAR}" -C /usr/local/src/
if [ $? -ne 0 ]; then
    color "解压 Nginx 源码失败" 1
    exit 1
fi

# 编译安装
cd "${NGINX_SRC_DIR}" || { color "源码目录不存在：${NGINX_SRC_DIR}" 1; exit 1; }
echo "开始编译安装 Nginx 到 ${NGINX_PREFIX}"
./configure \
    --prefix=${NGINX_PREFIX} \
    --user=nginx \
    --group=nginx \
    --sbin-path=${NGINX_PREFIX}/nginx \
    --conf-path=${NGINX_PREFIX}/conf/nginx.conf \
    --error-log-path=/var/log/nginx/nginx.log \
    --http-log-path=/var/log/nginx/access.log \
    --modules-path=${NGINX_PREFIX}/modules \
    --with-select_module \
    --with-poll_module \
    --with-threads \
    --with-http_ssl_module \
    --with-http_v2_module \
    --with-http_realip_module \
    --with-http_image_filter_module \
    --with-http_sub_module \
    --with-http_flv_module \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_stub_status_module \
    --with-stream \
    --with-http_addition_module

if [ $? -ne 0 ]; then
    color "configure 失败，请检查依赖是否齐全" 1
    exit 1
fi

echo "执行编译和安装"
make && make install
if [ $? -ne 0 ]; then
    color "编译或安装失败" 1
    exit 1
fi

# 配置 systemd 服务
echo "配置 systemd 服务"
cat >/usr/lib/systemd/system/nginx.service<<EOF
[Unit]
Description=nginx - high performance web server
After=network.target

[Service]
Type=forking
ExecStart=${NGINX_PREFIX}/nginx
ExecReload=${NGINX_PREFIX}/nginx -s reload
ExecStop=${NGINX_PREFIX}/nginx -s stop
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
if [ $? -ne 0 ]; then
    color "systemd 服务配置失败，但不影响 Nginx 使用" 2
fi

# 配置环境变量
echo "配置环境变量到 /etc/profile"
if ! grep -q "NGINX_HOME=${NGINX_PREFIX}" /etc/profile; then
cat >>/etc/profile <<EOF
# nginx
export NGINX_HOME=${NGINX_PREFIX}
export PATH=\$PATH:\$NGINX_HOME
EOF
    source /etc/profile
    color "环境变量配置完成" 0
else
    color "环境变量已存在，跳过配置" 2
fi

# 启动并验证
echo "启动 Nginx 服务"
${NGINX_PREFIX}/nginx
if [ $? -eq 0 ]; then
    color "Nginx 启动成功" 0
    echo "版本信息：$( ${NGINX_PREFIX}/nginx -v 2>&1 )"
    echo "配置文件：${NGINX_PREFIX}/conf/nginx.conf"
    echo "访问测试：http://<你的服务器IP>"
    echo ""
    echo "Nginx 进程列表："
    ps -ef | grep nginx | grep -v grep
    echo ""
    echo "常用命令："
    echo "  启动：${NGINX_PREFIX}/nginx"
    echo "  停止：${NGINX_PREFIX}/nginx -s stop"
    echo "  重载：${NGINX_PREFIX}/nginx -s reload"
    echo "  测试：${NGINX_PREFIX}/nginx -t"
    echo "  systemd 管理：systemctl start/stop/restart/status nginx"
else
    color "Nginx 启动失败，请查看日志 /var/log/nginx/nginx.log" 1
    exit 1
fi
