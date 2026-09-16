#!/bin/bash
#
#********************************************************************
#Author:           YiLing Wu (hj)
#email:            huangjing510@126.com
#Date:             2026-05-28 16:27:32
#FileName:         spring-boot-helloworld.sh
#URL:              https://script.huangjingblog.cn
#Description:      SpringBoot HelloWorld测试项目批量发布脚本 
#Copyright (C):    2026 All rights reserved
#********************************************************************
APP=spring-boot-helloworld
APP_PATH=/data/${APP}

HOST_LIST="
10.0.0.112
10.0.0.113
"

PORT=8888

mvn clean package -Dmaven.test.skip=true

for host in $HOST_LIST;do
    ssh root@$host "[ -e $APP_PATH ] || mkdir -p $APP_PATH"
    ssh root@$host killall -9 java &> /dev/null
    scp target/${APP}-0.6-SNAPSHOT.jar root@$host:${APP_PATH}/${APP}.jar
    ##ssh root@$host "java -jar ${APP_PATH}/${APP}.jar --server.port=8888 &"
    ssh root@$host "nohup java -jar ${APP_PATH}/${APP}.jar --server.port=$PORT &>/dev/null &"
done
