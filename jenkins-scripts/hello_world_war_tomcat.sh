#!/bin/bash
#
#********************************************************************
#Author:           YiLing Wu (hj)
#email:            huangjing510@126.com
#Date:             2026-05-21 20:29:24
#FileName:         hello_world_war_tomcat.sh
#URL:              https://script.huangjingblog.cn
#Description:      部署 hello world WAR 包到 Tomcat 集群（多主机滚动部署）
#Copyright (C):    2026 All rights reserved
#********************************************************************
APP_TAR_PATH=/data/tomcat/appdir
APP_PATH=/data/tomcat/webdir
#APP_DEPLOY_PATH=/usr/local/tomcat/webapps/hello # 手动解压安装的 tomcat 通常在 /usr/local/tomcat/webapps/
APP_DEPLOY_PATH=/var/lib/tomcat/webapps/hello # Rocky 9.8 yum安装tomcat的默认webapps路径，非/usr/local/tomcat
DATE=$(date +%F-%s)
HOST_LIST="
10.0.0.112
10.0.0.113
10.0.0.114
"

tar -C "$WORKSPACE/src/main/webapp/" -cf hello.tar .
for host in $HOST_LIST;do
    scp hello.tar $host:${APP_TAR_PATH}/hello-${DATE}.tar
    ssh $host "systemctl stop tomcat &&  \
            mkdir ${APP_PATH}/hello-${DATE} && \
            tar xf  ${APP_TAR_PATH}/hello-${DATE}.tar -C ${APP_PATH}/hello-${DATE} && \
            rm -f \"$APP_DEPLOY_PATH\" && \
            ln -s \"${APP_PATH}/hello-${DATE}\" \"$APP_DEPLOY_PATH\" && \
            systemctl start tomcat"
done
