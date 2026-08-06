#!/bin/bash
#
#********************************************************************
#Author:           YiLing Wu (hj)
#email:            huangjing510@126.com
#Date:             2026-05-28 17:27:22
#FileName:         monitor-html.sh
#URL:              https://script.huangjingblog.cn
#Description:      用于wheel应用的自动化部署和回滚脚本 
#Copyright (C):    2026 All rights reserved
#********************************************************************
# 定义需要部署/回滚的目标服务器列表
HOST_LIST="
10.0.0.112
10.0.0.113
10.0.0.114
"

# 应用名称
APP=wheel
# 应用部署的目标路径（软链接指向实际版本目录）
#APP_PATH=/var/www/html
APP_PATH=/usr/share/nginx/html # rocky nginx html默认路径（2026.07.21 测试）
# 应用版本包存储的根目录
DATA_PATH=/opt
# 获取当前时间戳，用于版本目录命名（格式：年-月-日_时-分-秒）
DATE=`date +%F_%H-%M-%S`

# 部署函数：将应用包部署到目标服务器
deploy () {
    # 遍历目标服务器列表
    for i in ${HOST_LIST};do
        # 1. 远程删除旧的部署软链接，创建新版本目录（-p自动创建父目录，-v显示创建过程）
        ssh root@$i "rm -rf  ${APP_PATH} && mkdir -pv ${DATA_PATH}/${APP}-${DATE}"
        # 2. 将当前目录下的所有文件拷贝到目标服务器的新版本目录
        scp -r * root@$i:${DATA_PATH}/${APP}-${DATE}
        # 3. 创建软链接，将部署路径指向新版本目录
        ssh root@$i "ln -sv ${DATA_PATH}/${APP}-${DATE} ${APP_PATH}"
    done
}

# 回滚函数：将应用回滚到上一个版本
rollback() {
    # 遍历目标服务器列表
    for i in ${HOST_LIST};do
        # 1. 获取当前部署路径指向的实际版本目录（读取软链接的源路径）
        CURRENT_VERISION=$(ssh root@$i "readlink $APP_PATH")
        # 2. 提取版本目录的basename（去掉路径，仅保留版本名）
        CURRENT_VERISION=$(basename ${CURRENT_VERISION})
        echo "当前服务器$i的应用版本为：${CURRENT_VERISION}"
        
        # 3. 列出版本存储目录下的所有目录，找到当前版本的上一个版本
        PRE_VERSION=$(ssh root@$i "ls -1 ${DATA_PATH} | grep -B1 ${CURRENT_VERISION}|head -n1 ")
        echo "服务器$i需要回滚到的版本为：$PRE_VERSION"
        
        # 4. 删除当前软链接，重新创建软链接指向上一个版本目录
        ssh root@$i "rm -f  ${APP_PATH}&& ln -sv ${DATA_PATH}/${PRE_VERSION} ${APP_PATH}"
    done
}

# 脚本入口：根据传入的参数执行对应操作
case $1 in
deploy)   # 执行部署操作（参数为deploy时）
   deploy
   ;;
rollback) # 执行回滚操作（参数为rollback时）
   rollback
   ;;
*)        # 无有效参数时直接退出脚本
    exit
   ;;
esac
