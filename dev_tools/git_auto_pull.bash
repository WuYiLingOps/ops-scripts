#!/bin/bash
#
#********************************************************************
#Author:           YiLing Wu (hj)
#email:            huangjing510@126.com
#Date:             2026-06-28 21:57:02
#FileName:         git_auto_pull.bash
#URL:              https://script.huangjingblog.cn
#Description:      Git仓库自动拉取脚本，支持定时任务自动同步远程最新代码
#Copyright (C):    2026 All rights reserved
#********************************************************************

# ==================== 定时任务配置说明 ====================
#
# 1. 添加定时任务（每2小时自动执行一次）：
#    crontab -e
#
# 2. 在crontab编辑器中添加以下行：
#    # Git仓库自动拉取任务（每2小时执行一次）
#    0 */2 * * * /path/to/git_auto_pull.bash -r /path/to/repo -l /path/to/logs/git_pull.log
#
# 3. 参数说明：
#    -r  指定Git仓库路径（必填）
#    -l  指定日志文件路径（可选，默认当前目录）
#
# 4. 测试脚本是否正常运行：
#    /path/to/git_auto_pull.bash -r /path/to/repo -l /tmp/git_pull.log

# ==================== 颜色定义 ====================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ==================== 日志函数 ====================
log_info() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] [INFO]${RESET} $1"
    [ -n "${LOG_FILE}" ] && echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $1" >> "${LOG_FILE}"
}
log_warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] [WARN]${RESET} $1"
    [ -n "${LOG_FILE}" ] && echo "[$(date +'%Y-%m-%d %H:%M:%S')] [WARN] $1" >> "${LOG_FILE}"
}
log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR]${RESET} $1"
    [ -n "${LOG_FILE}" ] && echo "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $1" >> "${LOG_FILE}"
}

# ==================== 显示帮助 ====================
show_help() {
    echo -e "${CYAN}用法:${RESET} $0 [选项]"
    echo ""
    echo -e "${CYAN}选项:${RESET}"
    echo "  -r <repo_path>   指定Git仓库路径（必填）"
    echo "  -l <log_file>    指定日志文件路径（可选）"
    echo "  -b <branch>      指定拉取的分支（默认：当前分支）"
    echo "  -h, --help       显示此帮助信息"
    echo ""
    echo -e "${CYAN}示例:${RESET}"
    echo "  $0 -r /data/scripts -l /var/log/git_pull.log"
    echo "  $0 -r /data/scripts -b master"
    echo ""
    echo -e "${CYAN}定时任务配置:${RESET}"
    echo "  每2小时自动执行（在脚本头部查看详细说明）"
    echo "  crontab: 0 */2 * * * $0 -r /data/scripts -l /var/log/git_pull.log"
}

# ==================== 检查仓库是否为Git仓库 ====================
check_git_repo() {
    local repo_path="$1"

    if [ ! -d "${repo_path}" ]; then
        log_error "目录不存在: ${repo_path}"
        exit 1
    fi

    if [ ! -d "${repo_path}/.git" ]; then
        log_error "不是有效的Git仓库: ${repo_path}"
        exit 1
    fi

    cd "${repo_path}" || exit 1
    log_info "进入Git仓库: ${repo_path}"
}

# ==================== 执行Git拉取 ====================
git_pull() {
    local branch="$1"

    # 获取当前分支
    current_branch=$(git symbolic-ref --short HEAD 2>/dev/null)
    if [ -z "${current_branch}" ]; then
        current_branch="HEAD detached"
        log_warn "当前处于 detached HEAD 状态"
    fi

    # 使用指定分支或当前分支
    target_branch="${branch:-${current_branch}}"
    log_info "目标分支: ${target_branch}"

    # 保存当前状态
    local_before=$(git rev-parse HEAD 2>/dev/null)

    # 执行拉取
    log_info "开始拉取最新代码..."
    pull_output=$(git pull origin "${target_branch}" 2>&1)
    pull_exit_code=$?

    if [ ${pull_exit_code} -eq 0 ]; then
        local_after=$(git rev-parse HEAD 2>/dev/null)

        if [ "${local_before}" = "${local_after}" ]; then
            log_info "当前已是最新代码，无更新"
            return 0
        else
            log_info "拉取成功，已更新到最新版本"
            log_info "更新前: ${local_before:0:8}"
            log_info "更新后: ${local_after:0:8}"
            return 0
        fi
    else
        log_error "拉取失败: ${pull_output}"
        return 1
    fi
}

# ==================== 显示仓库状态 ====================
show_status() {
    log_info "当前仓库状态:"
    git status -s
    log_info "最近提交:"
    git log --oneline -3
}

# ==================== 主函数 ====================
main() {
    # 默认参数
    REPO_PATH=""
    LOG_FILE=""
    BRANCH=""

    # 解析参数
    while [ $# -gt 0 ]; do
        case "$1" in
            -r)
                REPO_PATH="$2"
                shift 2
                ;;
            -l)
                LOG_FILE="$2"
                shift 2
                ;;
            -b)
                BRANCH="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # 检查必填参数
    if [ -z "${REPO_PATH}" ]; then
        log_error "必须指定仓库路径 (-r)"
        show_help
        exit 1
    fi

    # 创建日志目录
    if [ -n "${LOG_FILE}" ]; then
        log_dir=$(dirname "${LOG_FILE}")
        mkdir -p "${log_dir}" 2>/dev/null
    fi

    # 执行主流程
    log_info "================================================================"
    log_info "          Git仓库自动拉取任务"
    log_info "================================================================"

    check_git_repo "${REPO_PATH}"
    git_pull "${BRANCH}"

    echo ""
    log_info "任务完成时间: $(date +'%Y-%m-%d %H:%M:%S')"
    log_info "================================================================"
}

main "$@"
