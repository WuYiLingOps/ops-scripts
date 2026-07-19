#!/bin/bash
#
#********************************************************************
#Author:           YiLing Wu (hj)
#email:            huangjing510@126.com
#Date:             2026-05-02 17:58:03
#FileName:         install_nginx.bash
#URL:              https://script.huangjingblog.cn
#Description:      通用 Nginx 编译安装脚本，支持 RedHat/CentOS/Rocky/Ubuntu/Debian 等主流系统
#                  - sudo bash install_nginx_universal.bash           # 默认安装 1.24.0
#                  - sudo bash install_nginx_universal.bash 1.26.0    # 安装指定版本
#Copyright (C):    2026 All rights reserved
#********************************************************************



# ==================== 颜色定义 ====================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
BOLD='\033[1m'
RESET='\033[0m'

# ==================== 函数定义 ====================
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

# ==================== 使用说明 ====================
show_usage() {
    echo "使用方法："
    echo "  sudo bash $0 [版本号]"
    echo ""
    echo "示例："
    echo "  sudo bash $0           # 默认安装 1.24.0"
    echo "  sudo bash $0 1.26.0    # 安装指定版本 1.26.0"
    echo ""
}

# ==================== 基础检查 ====================
if [ "$EUID" -ne 0 ]; then
    log_error "请以 root 或 sudo 权限执行此脚本"
    exit 1
fi

# ==================== 配置变量 ====================
# 支持命令行参数传递版本号，默认 1.24.0
NGINX_VERSION="${1:-1.24.0}"
NGINX_PREFIX="/usr/local/nginx"
NGINX_TAR="nginx-${NGINX_VERSION}.tar.gz"
NGINX_SRC_DIR="/opt/nginx-${NGINX_VERSION}"

log_info "准备安装 Nginx 版本：${NGINX_VERSION}"

# ==================== 系统识别 ====================
log_step "识别操作系统类型"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    log_info "检测到系统：$PRETTY_NAME"
elif [ -f /etc/redhat-release ]; then
    OS="centos"
    log_info "检测到系统：CentOS/RHEL"
else
    log_error "无法识别操作系统类型"
    exit 1
fi

# ==================== 安装依赖 ====================
log_step "安装依赖包"
case $OS in
    ubuntu|debian)
        log_info "使用 apt-get 安装依赖"
        apt-get update -y
        apt-get install -y \
            build-essential \
            libpcre3 libpcre3-dev \
            zlib1g-dev \
            libssl-dev \
            libgd-dev libpng-dev libjpeg-dev libfreetype6-dev \
            wget curl
        if [ $? -ne 0 ]; then
            log_error "依赖安装失败"
            exit 1
        fi
        NOLOGIN_PATH="/usr/sbin/nologin"
        ;;
    centos|rhel|fedora|rocky|almalinux|amzn)
        log_info "使用 yum 安装依赖"
        yum install -y gcc gcc-c++ automake openssl openssl-devel make pcre-devel gd-devel wget curl
        if [ $? -ne 0 ]; then
            log_error "依赖安装失败"
            exit 1
        fi
        NOLOGIN_PATH="/sbin/nologin"
        ;;
    *)
        log_error "不支持的操作系统：$OS"
        exit 1
        ;;
esac

# ==================== 创建 nginx 用户 ====================
if id nginx >/dev/null 2>&1; then
    log_warn "用户 nginx 已存在，跳过创建"
else
    log_step "创建 nginx 用户"
    useradd -s $NOLOGIN_PATH -M nginx
    if [ $? -ne 0 ]; then
        log_error "创建 nginx 用户失败"
        exit 1
    fi
fi

# ==================== 创建日志目录 ====================
log_step "创建日志目录"
mkdir -p /var/log/nginx
if [ $? -ne 0 ]; then
    log_error "创建日志目录失败"
    exit 1
fi

# ==================== 下载并解压源码 ====================
log_step "准备 Nginx 源码包版本 ${NGINX_VERSION}"
if [ -f "${NGINX_TAR}" ]; then
    log_warn "检测到本地源码包 ${NGINX_TAR}，跳过下载"
else
    log_info "从官方下载 Nginx 源码"
    wget "https://nginx.org/download/${NGINX_TAR}"
    if [ $? -ne 0 ]; then
        log_error "下载 Nginx 源码失败，请检查网络或版本号"
        exit 1
    fi
fi

log_step "解压源码包到 /opt/"
tar -xzf "${NGINX_TAR}" -C /opt/
if [ $? -ne 0 ]; then
    log_error "解压 Nginx 源码失败"
    exit 1
fi

# ==================== 编译安装 ====================
cd "${NGINX_SRC_DIR}" || { log_error "源码目录不存在：${NGINX_SRC_DIR}"; exit 1; }
log_step "开始编译安装 Nginx 到 ${NGINX_PREFIX}"
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
    log_error "configure 失败，请检查依赖是否齐全"
    exit 1
fi

log_step "执行编译和安装"
make && make install
if [ $? -ne 0 ]; then
    log_error "编译或安装失败"
    exit 1
fi

# ==================== 配置 systemd 服务 ====================
log_step "配置 systemd 服务"
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
    log_warn "systemd 服务配置失败，但不影响 Nginx 使用"
fi

# ==================== 配置环境变量 ====================
log_step "配置环境变量到 /etc/profile"
if ! grep -q "NGINX_HOME=${NGINX_PREFIX}" /etc/profile; then
cat >>/etc/profile <<EOF
# nginx
export NGINX_HOME=${NGINX_PREFIX}
export PATH=\$PATH:\$NGINX_HOME
EOF
    source /etc/profile
    log_info "环境变量配置完成"
else
    log_warn "环境变量已存在，跳过配置"
fi

# ==================== 启动并验证 ====================
log_step "启动 Nginx 服务"
${NGINX_PREFIX}/nginx
if [ $? -eq 0 ]; then
    log_info "✅ Nginx 启动成功"
    log_info "版本信息：$( ${NGINX_PREFIX}/nginx -v 2>&1 )"
    log_info "配置文件：${NGINX_PREFIX}/conf/nginx.conf"
    log_info "访问测试：http://<你的服务器IP>"
    echo ""
    log_info "Nginx 进程列表："
    ps -ef | grep nginx | grep -v grep
    echo ""
    log_info "常用命令："
    echo "  启动：${NGINX_PREFIX}/nginx"
    echo "  停止：${NGINX_PREFIX}/nginx -s stop"
    echo "  重载：${NGINX_PREFIX}/nginx -s reload"
    echo "  测试：${NGINX_PREFIX}/nginx -t"
    echo "  systemd 管理：systemctl start/stop/restart/status nginx"
else
    log_error "Nginx 启动失败，请查看日志 /var/log/nginx/nginx.log"
    exit 1
fi
