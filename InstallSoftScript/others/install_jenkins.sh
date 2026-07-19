#!/bin/bash
#
#********************************************************************
#Author:           YiLing Wu (hj)
#email:            huangjing510@126.com
#Date:             2024-02-04
#FileName:         install_jenkins.sh
#URL:              https://script.huangjingblog.cn
#Description:      自动化安装Jenkins（适配CentOS/Rocky/Ubuntu）
#Copyright (C):    2024 All rights reserved
#********************************************************************

# 定义Jenkins安装包下载地址（CentOS/Rocky用RPM包，Ubuntu用DEB包，按需注释切换）
# 2025-12-11 清华源最新版本
#URL="https://mirrors.tuna.tsinghua.edu.cn/jenkins/redhat-stable/jenkins-2.528.3-1.1.noarch.rpm"
# 2025-12-09 清华源最新版本
URL="https://mirrors.tuna.tsinghua.edu.cn/jenkins/debian-stable/jenkins_2.528.3_all.deb"
# 阿里源
#URL="https://mirrors.aliyun.com/jenkins/debian-stable/jenkins_2.289.3_all.deb"

# 定义颜色输出变量
GREEN="echo -e \E[32;1m"
END="\E[0m"
# 获取本机第一个IP地址（用于拼接访问链接）
HOST=`hostname -I|awk '{print $1}'`
# 加载系统版本信息（区分CentOS/Rocky/Ubuntu）
. /etc/os-release

# 定义自定义安装路径和相关配置
DOWNLOAD_DIR="/usr/local/src"                  # 下载目录
JENKINS_PACKAGE=$(basename $URL)                # 安装包文件名
PACKAGE_PATH="$DOWNLOAD_DIR/$JENKINS_PACKAGE"  # 完整安装包路径

# 定义颜色输出函数（用于操作结果提示）
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

# 安装Java依赖（适配不同系统）
install_java(){
    if [ $ID = "centos" -o $ID = "rocky" ];then
       yum -y install java-21-openjdk-devel  # CentOS/Rocky安装OpenJDK 21 2026.07.19
    else
       apt update                        # Ubuntu更新源
       apt -y install openjdk-21-jdk      # Ubuntu安装OpenJDK 21
    fi
    if [ $? -eq 0 ];then
       color "安装java完成!" 0  # 安装成功提示
    else
       color "安装java失败!" 1  # 安装失败提示并退出
       exit
    fi
}

# 下载并安装Jenkins（适配不同系统）
install_jenkins() {
    # 检查安装包是否已存在
    if [ -f "$PACKAGE_PATH" ]; then
        color "安装包 $JENKINS_PACKAGE 已存在，跳过下载!" 0
    else
        # 下载安装包到指定目录，失败则提示并退出
        wget -P $DOWNLOAD_DIR/ $URL || { color  "下载失败!" 1 ;exit ; }
    fi
    
    if [ $ID = "centos" -o $ID = "rocky" ];then
       yum -y install $PACKAGE_PATH  # CentOS/Rocky安装RPM包
       systemctl enable jenkins      # 设置开机自启
       systemctl start jenkins       # 启动Jenkins
    else
       # Ubuntu安装依赖包（daemon/net-tools），失败则退出
       apt -y install daemon net-tools || { color  "安装依赖包失败!" 1 ;exit ; }
       dpkg -i $PACKAGE_PATH         # Ubuntu安装DEB包
    fi
    if [ $? -eq 0 ];then
       color "安装Jenkins完成!" 0  # 安装成功提示
    else
       color "安装Jenkins失败!" 1  # 安装失败提示并退出
       exit
    fi
}

# 验证Jenkins启动状态并输出访问信息+初始密码
start_jenkins() {
    # 检查Jenkins是否活跃
    systemctl is-active jenkins
    if [ $?  -eq 0 ];then  
        echo
        color "Jenkins安装完成!" 0
        echo "-------------------------------------------------------------------"
        echo -e "访问链接: \c"
        ${GREEN}"http://$HOST:8080/"${END}  # 输出绿色的访问链接
    else
        color "Jenkins安装失败!" 1  # 启动失败提示并退出
        exit
    fi
    # 循环等待初始密码文件生成，生成后读取密码并输出
    while :;do
        [ -f /var/lib/jenkins/secrets/initialAdminPassword ] && { 
            key=`cat /var/lib/jenkins/secrets/initialAdminPassword` ; 
            break; 
        }
        sleep 1
    done
    echo -e "登录秘钥: \c"
    ${GREEN}$key${END}  # 输出绿色的初始登录密码
}

# 执行安装流程
install_java
install_jenkins
start_jenkins
