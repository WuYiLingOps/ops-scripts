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
    sudo prime-select nvidia && echo "已切换到独显模式，重启后生效"
    ;;
  intel)
    sudo prime-select intel && echo "已切换到核显模式，重启后生效"
    ;;
  hybrid)
    sudo prime-select on-demand && echo "已切换到混合模式，重启后生效"
    ;;
  *)
    echo -e "当前模式: \033[1;32m$(prime-select query)\033[0m"
    echo "用法: gpu-switch [nvidia|intel|hybrid]"
    ;;
esac
