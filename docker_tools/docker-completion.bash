#!/bin/bash
#
#********************************************************************
#Author:           YiLing Wu (hj)
#email:            huangjing510@126.com
#Date:             2023-12-23
#FileName:         docker-completion.bash
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

# 配置 bashrc
configure_bashrc() {
    local bashrc="$HOME/.bashrc"

    # 检查是否已配置 bash-completion
    if grep -q "bash-completion" "$bashrc" 2>/dev/null; then
        echo -e "${GREEN}bashrc 中已配置 bash-completion${NC}"
    else
        echo -e "${YELLOW}正在配置 bashrc...${NC}"
        cat >> "$bashrc" << 'EOF'

# bash-completion configuration
if [ -f /usr/share/bash-completion/bash_completion ]; then
    source /usr/share/bash-completion/bash_completion
fi
EOF
        echo -e "${GREEN}bashrc 配置完成${NC}"
    fi
}

# 检查并创建 docker 补全文件
setup_docker_completion() {
    local completion_dir="/usr/share/bash-completion/completions"
    local docker_completion="$completion_dir/docker"

    if [ -f "$docker_completion" ]; then
        echo -e "${GREEN}docker 补全文件已存在${NC}"
    elif command -v docker &>/dev/null; then
        echo -e "${YELLOW}正在生成 docker 补全文件...${NC}"
        sudo mkdir -p "$completion_dir"
        docker completion bash | sudo tee "$docker_completion" > /dev/null
        if [ -f "$docker_completion" ]; then
            echo -e "${GREEN}docker 补全文件生成成功${NC}"
        else
            echo -e "${YELLOW}警告: docker 补全文件生成失败，可能需要手动配置${NC}"
        fi
    else
        echo -e "${YELLOW}警告: docker 未安装，跳过补全配置${NC}"
        return 1
    fi
}

# 主函数
main() {
    echo -e "${BOLD}${CYAN}=== Docker 自动补全配置脚本 ===${NC}"
    echo ""

    # 检查是否已安装 bash-completion
    echo -e "${CYAN}[1/3] 检查 bash-completion...${NC}"
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        echo -e "${GREEN}bash-completion 已安装${NC}"
    else
        echo -e "${YELLOW}正在安装 bash-completion...${NC}"
        install_bash_completion
    fi
    echo ""

    # 配置 bashrc
    echo -e "${CYAN}[2/3] 配置 bashrc...${NC}"
    configure_bashrc
    echo ""

    # 设置 docker 补全
    echo -e "${CYAN}[3/3] 配置 docker 补全...${NC}"
    setup_docker_completion
    echo ""

    # 完成提示
    echo -e "${GREEN}${BOLD}=== 配置完成 ===${NC}"
    echo ""
    echo -e "${YELLOW}请执行以下命令使配置生效：${NC}"
    echo -e "  source ~/.bashrc"
    echo -e "  或者重新打开终端"
    echo ""
    echo -e "${CYAN}测试补全：输入 docker 然后按 Tab 键${NC}"
}

main "$@"
