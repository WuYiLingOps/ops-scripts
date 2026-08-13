#!/bin/bash
#
#********************************************************************
#Author:           YiLing Wu (hj)
#email:            huangjing510@126.com
#Date:             2026-08-13 18:57:30
#FileName:         switch-gpu-mode 
#URL:              https://script.huangjingblog.cn
#Description:      ubuntu 显卡模式切换脚本 
#Copyright (C):    2026 All rights reserved
#********************************************************************
case $1 in
  nvidia)
    sudo prime-select nvidia && echo -e "\033[1;32m已切换到独显模式，重启后生效\033[0m"
    ;;
  intel)
    sudo prime-select intel && echo -e "\033[1;34m已切换到核显模式，重启后生效\033[0m"
    ;;
  hybrid)
    sudo prime-select on-demand && echo -e "\033[1;33m已切换到混合模式，重启后生效\033[0m"
    ;;
  *)
    echo -e "当前模式: \033[1;32m$(prime-select query)\033[0m"
    echo "用法: switch-gpu-module [nvidia|intel|hybrid]"
    ;;
esac
