#!/bin/bash
#
#********************************************************************
#Author:           YiLing Wu (hj)
#email:            huangjing510@126.com
#Date:             2026-10-26 16:08:42
#FileName:         install_node_exporter.sh
#URL:              https://script.huangjingblog.cn
#Description:      The test script 
#Copyright (C):    2026 All rights reserved
#********************************************************************

#支持在线和离线安装，建议离线安装

NODE_EXPORTER_VERSION=1.9.1
#NODE_EXPORTER_VERSION=1.9.0
#NODE_EXPORTER_VERSION=1.8.2
#NODE_EXPORTER_VERSION=1.8.1
#NODE_EXPORTER_VERSION=1.7.0
#NODE_EXPORTER_VERSION=1.5.0
#NODE_EXPORTER_VERSION=1.4.0
#NODE_EXPORTER_VERSION=1.3.1
#NODE_EXPORTER_VERSION=1.2.2

NODE_EXPORTER_FILE="node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"
NODE_EXPORTER_URL=https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/${NODE_EXPORTER_FILE}

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


install_node_exporter () {
    if [ ! -f  ${NODE_EXPORTER_FILE} ] ;then
        wget ${GITHUB_PROXY}${NODE_EXPORTER_URL} ||  { color "下载失败!" 1 ; exit ; }
    fi
    [ -d $INSTALL_DIR ] || mkdir -p $INSTALL_DIR
    tar xf ${NODE_EXPORTER_FILE} -C $INSTALL_DIR
    cd $INSTALL_DIR &&  ln -s node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64 node_exporter
    mkdir -p $INSTALL_DIR/node_exporter/bin
    cd $INSTALL_DIR/node_exporter &&  mv node_exporter bin/ 
    id prometheus &> /dev/null || useradd -r -s /sbin/nologin prometheus
    chown -R prometheus:prometheus ${INSTALL_DIR}/node_exporter/
      
    cat >  /etc/profile.d/node_exporter.sh <<EOF
export NODE_EXPORTER_HOME=${INSTALL_DIR}/node_exporter
export PATH=\${NODE_EXPORTER_HOME}/bin:\$PATH
EOF

}


node_exporter_service () {
    cat > /lib/systemd/system/node_exporter.service <<EOF
[Unit]
Description=Prometheus Node Exporter
After=network.target

[Service]
Type=simple
ExecStart=$INSTALL_DIR/node_exporter/bin/node_exporter
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
User=prometheus
Group=prometheus

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable --now node_exporter.service
}


start_node_exporter() { 
    systemctl is-active node_exporter.service
    if [ $?  -eq 0 ];then  
        echo 
        color "node_exporter 安装完成!" 0
        echo "-------------------------------------------------------------------"
        echo -e "访问链接: \c"
        msg_info "http://$HOST:9100/metrics" 
    else
        color "node_exporter 安装失败!" 1
        exit
    fi 
}

install_node_exporter

node_exporter_service

start_node_exporter
