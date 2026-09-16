#!/bin/bash
#
#********************************************************************
#Author:           YiLing Wu (hj)
#email:            huangjing510@126.com
#Date:             2026-06-03 22:28:20
#FileName:         freestyle-ruoyi.sh
#URL:              https://script.huangjingblog.cn
#Description:      ruoyi部署
#Copyright (C):    2026 All rights reserved
#********************************************************************
APP=ruoyi
APP_PATH=/data/$APP
PORT=80

HOST_LIST="
10.0.0.112
10.0.0.113
"

mvn clean package -Dmaven.test.skip=true

for host in $HOST_LIST;do
    ssh root@$host "[ -e $APP_PATH ] || mkdir -p $APP_PATH"
    ssh root@$host killall -9 java &> /dev/null
    scp ruoyi-admin/target/*.jar root@$host:${APP_PATH}/${APP}.jar
    ssh root@$host "nohup java -jar ${APP_PATH}/${APP}.jar --server.port=${PORT} &>/dev/null &"&
done
