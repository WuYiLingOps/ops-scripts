#!/bin/bash
# ============================================================
# 文件名称：ssh-keygen-automated.sh
# 创建时间：2026-05-14
# 系统用户：Administrator
# 作　　者：無以菱
# 联系邮箱：huangjing510@126.com
# 功能描述：免交互 SSH 密钥生成与分发脚本
# 用法：./ssh-keygen-automated.sh [-P 密码]
# ============================================================

set -euo pipefail

# ==================== 配置区域 ====================
# SSH 密钥参数
KEY_TYPE="rsa"
KEY_BITS="2048"
KEY_FILE="$HOME/.ssh/id_rsa"

# 集群节点 IP
NODES=(
    "10.0.0.202"
    "10.0.0.203"
    "10.0.0.204"
    "10.0.0.205"
    "10.0.0.206"
    "10.0.0.207"
    "10.0.0.208"
)

# 密码：-P 参数传入或运行时交互输入
NODE_PASSWORD=""

# ==================== 颜色与日志 ====================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ==================== 前置依赖检查 ====================
# get_os_id 从 /etc/os-release 获取系统 ID
# @return 输出系统 ID（小写），如 debian、ubuntu、centos 等
get_os_id() {
    if [ -f /etc/os-release ]; then
        # shellcheck source=/dev/null
        . /etc/os-release
        echo "${ID}"
    else
        echo ""
    fi
}

# get_pkg_manager 根据系统类型返回包管理器安装命令
# @return 输出包管理器安装命令
get_pkg_manager() {
    local os_id
    os_id=$(get_os_id)

    case "${os_id}" in
        debian|ubuntu|linuxmint|pop)
            echo "apt-get install -y sshpass"
            ;;
        centos|rhel|rocky|alma|ol)
            echo "yum install -y sshpass"
            ;;
        fedora)
            echo "dnf install -y sshpass"
            ;;
        arch|manjaro)
            echo "pacman -S --noconfirm sshpass"
            ;;
        alpine)
            echo "apk add sshpass"
            ;;
        *)
            echo ""
            ;;
    esac
}

# check_deps 检查脚本运行所需的依赖程序
# @return 无返回值，依赖缺失时直接退出
check_deps() {
    if ! command -v sshpass &>/dev/null; then
        local install_cmd
        install_cmd=$(get_pkg_manager)
        if [ -z "${install_cmd}" ]; then
            log_error "sshpass 未安装，且无法检测系统类型，请手动安装"
        else
            log_error "sshpass 未安装，请先执行: ${install_cmd}"
        fi
        exit 1
    fi
}

# ==================== 生成密钥对（免交互） ====================
# generate_key 生成 SSH 密钥对
# 使用 ssh-keygen 免交互生成，支持 RSA 和 Ed25519 算法
# @return 无返回值，生成失败时直接退出
generate_key() {
    log_info "生成 SSH 密钥对..."
    mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"

    if [ -f "${KEY_FILE}" ]; then
        local backup="${KEY_FILE}.bak.$(date +%s)"
        log_warn "密钥已存在，备份至 ${backup}"
        cp "${KEY_FILE}" "${backup}"
        cp "${KEY_FILE}.pub" "${backup}.pub"
    fi

    # -N "" 空密码短语 -q 静默模式 -f 指定密钥路径
    ssh-keygen -t "${KEY_TYPE}" -b "${KEY_BITS}" -N "" -f "${KEY_FILE}" -q
    chmod 600 "${KEY_FILE}" && chmod 644 "${KEY_FILE}.pub"
    log_info "密钥生成成功 → ${KEY_FILE}"
}

# ==================== 分发公钥到所有节点 ====================
# distribute_keys 使用 ssh-copy-id 分发公钥到所有集群节点
# @return 0 全部成功, 1 存在失败节点
distribute_keys() {
    local total=${#NODES[@]} success=0 failed=0
    local failed_nodes=()

    log_info "开始分发公钥到 ${total} 个节点..."
    for i in "${!NODES[@]}"; do
        local node="${NODES[$i]}"
        printf "[%d/%d] %-20s" $((i + 1)) "${total}" "${node}"

        # sshpass 免交互 + ssh-copy-id 自动追加公钥
        # 注意：不能加 BatchMode=yes，否则 sshpass 无法传入密码
        if sshpass -p "${NODE_PASSWORD}" \
            ssh-copy-id \
                -o StrictHostKeyChecking=no \
                -o ConnectTimeout=10 \
                -i "${KEY_FILE}.pub" \
                "root@${node}" &>/dev/null; then
            echo -e " ${GREEN}✓ 成功${NC}"
            success=$((success + 1))
        else
            echo -e " ${RED}✗ 失败${NC}"
            failed=$((failed + 1))
            failed_nodes+=("${node}")
        fi
    done

    echo ""
    log_info "分发完成: ${success} 成功, ${failed} 失败"
    if [ ${failed} -gt 0 ]; then
        log_warn "失败节点列表:"
        for n in "${failed_nodes[@]}"; do log_warn "  - ${n}"; done
        return 1
    fi
    return 0
}

# ==================== 验证免密连接 ====================
# verify_connections 验证所有节点的 SSH 免密连接
# 通过 ssh 命令测试免密登录是否成功
# @return 无返回值，仅输出验证结果
verify_connections() {
    log_info "验证 SSH 免密连接..."
    local all_ok=true
    for node in "${NODES[@]}"; do
        printf "  %-20s" "${node}"
        if ssh -o ConnectTimeout=5 -o BatchMode=yes \
            "root@${node}" "echo ok" &>/dev/null; then
            echo -e "${GREEN} ✓${NC}"
        else
            echo -e "${RED} ✗${NC}"
            all_ok=false
        fi
    done
    [ "${all_ok}" = true ] && log_info "所有节点免密验证通过"
}

# ==================== 主流程 ====================
# main 脚本主函数，协调各模块执行
# @param $@ 命令行参数
# @return 无返回值，执行失败时直接退出
main() {
    # 解析命令行参数
    while getopts "P:" opt; do
        case $opt in
            P) NODE_PASSWORD="$OPTARG" ;;
            *) echo "用法: $0 [-P 密码]"; exit 1 ;;
        esac
    done

    # 未指定密码时交互输入
    if [ -z "${NODE_PASSWORD}" ]; then
        echo -n "请输入节点 root 密码: "
        read -s NODE_PASSWORD
        echo ""
        [ -z "${NODE_PASSWORD}" ] && { log_error "密码不能为空"; exit 1; }
    fi

    echo "============================================"
    echo "   SSH 免密密钥自动分发脚本"
    echo "   用途: Kubernetes 集群部署"
    echo "   节点: ${#NODES[@]} 个"
    echo "   密钥: ${KEY_TYPE}/${KEY_BITS}"
    echo "============================================"
    echo ""

    check_deps
    generate_key
    echo ""
    distribute_keys
    echo ""
    verify_connections

    echo ""
    log_info "全部执行完毕"
}

main "$@"
