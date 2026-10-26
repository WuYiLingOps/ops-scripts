#!/bin/bash
#
#********************************************************************
#Author:           YiLing Wu (hj)
#email:            huangjing510@126.com
#Date:             2026-10-26 16:10:08
#FileName:         install_prometheus.sh
#URL:              https://script.huangjingblog.cn
#Description:      The test script 
#Copyright (C):    2026 All rights reserved
#********************************************************************

#支持在线和离线安装,建议离线安装,在线下载很慢

PROMETHEUS_VERSION=3.5.0
#PROMETHEUS_VERSION=2.53.4
#PROMETHEUS_VERSION=3.2.1
#PROMETHEUS_VERSION=3.0.1
#PROMETHEUS_VERSION=2.53.2
#PROMETHEUS_VERSION=2.53.0
#PROMETHEUS_VERSION=2.50.1
#PROMETHEUS_VERSION=2.42.0
#PROMETHEUS_VERSION=2.39.1
#PROMETHEUS_VERSION=2.37.0
#PROMETHEUS_VERSION=2.30.3
#PROMETHEUS_VERSION=2.17.1

PROMETHEUS_FILE="prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz"
#PROMETHEUS_URL="https://mirrors.tuna.tsinghua.edu.cn/github-release/prometheus/prometheus/LatestRelease/${PROMETHEUS_FILE}"
PROMETHEUS_URL="https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/${PROMETHEUS_FILE}"

GITHUB_PROXY=https://mirror.ghproxy.com/


INSTALL_DIR=/usr/local

HOST=`hostname -I|awk '{print $1}'`


. /etc/os-release

msg_error() {
  echo -e "\033[1;31m$1\033[0m"
}

msg_info() {
  echo -e "\033[1;32m$1\033[0m"
}

msg_warn() {
  echo -e "\033[1;33m$1\033[0m"
}


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
        echo -n $"  OK  "    
    elif [ $2 = "failure" -o $2 = "1"  ] ;then 
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


install_prometheus () {
    if [ ! -f  ${PROMETHEUS_FILE} ] ;then
        wget ${GITHUB_PROXY}${PROMETHEUS_URL} ||  { color "下载失败!" 1 ; exit ; }
    fi
    [ -d $INSTALL_DIR ] || mkdir -p $INSTALL_DIR
    tar xf ${PROMETHEUS_FILE} -C $INSTALL_DIR
    cd $INSTALL_DIR &&  ln -s prometheus-${PROMETHEUS_VERSION}.linux-amd64 prometheus
    mkdir -p $INSTALL_DIR/prometheus/{bin,conf,data}
    cd $INSTALL_DIR/prometheus && { mv prometheus promtool bin/ ; mv prometheus.yml conf/; }
    id prometheus &>/dev/null || useradd -r -s /sbin/nologin prometheus
    chown -R prometheus:prometheus ${INSTALL_DIR}/prometheus/
    
    cat >>  /etc/profile <<EOF
export PROMETHEUS_HOME=${INSTALL_DIR}/prometheus
export PATH=\${PROMETHEUS_HOME}/bin:\$PATH
EOF

}


prometheus_service () {
    cat > /lib/systemd/system/prometheus.service <<EOF
[Unit]
Description=Prometheus Server
Documentation=https://prometheus.io/docs/introduction/overview/
After=network.target

[Service]
Restart=on-failure
User=prometheus
Group=prometheus
WorkingDirectory=${INSTALL_DIR}/prometheus
ExecStart=${INSTALL_DIR}/prometheus/bin/prometheus --config.file=${INSTALL_DIR}/prometheus/conf/prometheus.yml --web.enable-lifecycle
ExecReload=/bin/kill -HUP \$MAINPID
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable --now prometheus.service
}


start_prometheus() { 
    systemctl is-active prometheus
    if [ $?  -eq 0 ];then  
        echo 
        color "Prometheus 安装完成!" 0
        echo "-------------------------------------------------------------------"
        echo -e "访问链接: \c"
        msg_info "http://$HOST:9090/" 
    else
        color "Prometheus 安装失败!" 1
        exit
    fi 
}

install_prometheus
prometheus_service
start_prometheus
