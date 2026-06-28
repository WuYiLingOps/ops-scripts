#!/bin/bash
#
#********************************************************************
#Author:           YiLing Wu (hj)
#email:            huangjing510@126.com
#Date:             2023-12-23
#FileName:         docker-自动补全.bash
#URL:              http://huangjingblog.cn:510/
#Description:      配置Docker自动补全
#Copyright (C):    2024 All rights reserved
#********************************************************************
#

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# 检测系统包管理器
detect_package_manager() {
    if [ -f /etc/os-release ]; then
        # 优先检查 ID_LIKE 字段（适用于衍生版）
        if grep -q "ID_LIKE=.*debian" /etc/os-release 2>/dev/null; then
            echo "apt"
            return
        elif grep -q "ID_LIKE=.*rhel" /etc/os-release 2>/dev/null; then
            echo "yum"
            return
        fi

        # 检查 ID 字段
        local id
        id=$(grep "^ID=" /etc/os-release | cut -d'=' -f2 | tr -d '"')
        case "$id" in
            debian|ubuntu|linuxmint|pop)
                echo "apt"
                ;;
            centos|rhel|fedora|rocky|alma|amzn|ol)
                echo "yum"
                ;;
            *)
                echo "unknown"
                ;;
        esac
    else
        # 无 /etc/os-release 时尝试命令检测
        if command -v apt-get &>/dev/null; then
            echo "apt"
        elif command -v yum &>/dev/null; then
            echo "yum"
        else
            echo "unknown"
        fi
    fi
}

# 安装 bash-completion
install_bash_completion() {
    local pkg_mgr
    pkg_mgr=$(detect_package_manager)

    echo -e "${CYAN}检测到系统包管理器: ${GREEN}${BOLD}$pkg_mgr${NC}"

    case "$pkg_mgr" in
        apt)
            sudo apt-get update -qq
            sudo apt-get install -y bash-completion
            ;;
        yum)
            sudo yum install -y bash-completion
            ;;
        *)
            echo -e "${RED}${BOLD}错误: 不支持的系统或包管理器，请手动安装 bash-completion${NC}"
            exit 1
            ;;
    esac
}

# 加载补全配置
load_completions() {
    # 加载 bash 补全
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        source /usr/share/bash-completion/bash_completion
    else
        echo -e "${YELLOW}警告: 未找到 bash-completion 配置文件${NC}"
        return 1
    fi

    # 加载 docker 补全
    if [ -f /usr/share/bash-completion/completions/docker ]; then
        source /usr/share/bash-completion/completions/docker
    elif command -v docker &>/dev/null; then
        # 如果 docker 存在但补全文件不存在，尝试生成
        echo -e "${YELLOW}尝试生成 docker 补全...${NC}"
        docker completion bash > /usr/share/bash-completion/completions/docker 2>/dev/null && \
            source /usr/share/bash-completion/completions/docker
    else
        echo -e "${YELLOW}警告: 未找到 docker 补全配置文件${NC}"
        return 1
    fi
}

# 主函数
main() {
    echo -e "${BOLD}${CYAN}=== Docker 自动补全配置脚本 ===${NC}"

    # 检查是否已安装 bash-completion
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        echo -e "${GREEN}bash-completion 已安装${NC}"
    else
        echo -e "${YELLOW}正在安装 bash-completion...${NC}"
        install_bash_completion
    fi

    # 加载补全
    echo -e "${CYAN}加载补全配置...${NC}"
    load_completions

    echo -e "${GREEN}${BOLD}配置完成！${NC}"
}

main "$@"
