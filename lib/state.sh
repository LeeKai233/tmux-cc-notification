#!/bin/bash
# state.sh - State management module / 状态管理模块
# Manages task state files based on session_id
# SEC-2026-0112-0409 H2 修复：路径遍历防护
# SEC-2026-0112-0409 L4：debug 模式下记录操作失败

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/constants.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/validate.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/log.sh" 2>/dev/null || true

# Use constant or default / 使用常量或默认值
# 修改：使用子目录结构而非后缀拼接
STATE_BASE_DIR="${STATE_BASE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/cc-notify}"

# Atomic write helper - prevents race conditions / 原子写入 - 防止竞态条件
# SEC-2026-0112-0409 修复：使用 mktemp 防止竞态攻击
atomic_write() {
    local file="$1"
    local content="$2"
    local tmp
    tmp=$(mktemp "${file}.XXXXXX") || return 1
    chmod 600 "$tmp"
    printf '%s' "$content" > "$tmp" && mv "$tmp" "$file"
}

# Get state directory path / 获取状态目录路径
# SEC-2026-0112-0409 修复：添加 session_id 校验和路径断言
get_state_dir() {
    local session_id="$1"
    local safe_id
    safe_id=$(validate_session_id "$session_id") || return 1

    # 使用子目录结构：/tmp/cc-notify/{session_id}
    local state_dir="${STATE_BASE_DIR}/${safe_id}"

    # 二次验证路径在 base_dir 内
    validate_path_in_base "$state_dir" "$STATE_BASE_DIR" >/dev/null || return 1

    echo "$state_dir"
}

# Initialize state directory / 初始化状态目录
# SEC-2026-0112-0409 修复：使用 umask 确保权限
init_state() {
    local session_id="$1"
    local state_dir
    state_dir=$(get_state_dir "$session_id") || return 1

    # 确保 base 目录存在
    if [[ ! -d "$STATE_BASE_DIR" ]]; then
        (umask 077 && mkdir -p "$STATE_BASE_DIR")
        chmod 700 "$STATE_BASE_DIR"
    fi

    # 创建 session 目录
    (umask 077 && mkdir -p "$state_dir")
    chmod 700 "$state_dir"

    echo "$state_dir"
}

# Cleanup state directory / 清理状态目录
# SEC-2026-0112-0409 M5 修复：二次路径验证 + PID 归属验证 + 两阶段终止
cleanup_state() {
    local session_id="$1"
    local state_dir
    state_dir=$(get_state_dir "$session_id") || return 1

    # 二次验证路径在 base_dir 内（防御性编程）
    validate_path_in_base "$state_dir" "$STATE_BASE_DIR" >/dev/null || return 1

    # Kill background monitor process first / 先杀掉后台监控进程
    # SEC-2026-0112-0409 M5：验证 PID 归属 + 两阶段终止
    # SEC-2026-0112-0409 L4：debug 模式下记录终止操作
    if [[ -f "${state_dir}/monitor.pid" ]]; then
        local pid
        pid=$(cat "${state_dir}/monitor.pid" 2>/dev/null)
        if [[ -n "$pid" ]] && [[ -d "/proc/$pid" ]]; then
            local cmdline
            cmdline=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null)
            if [[ "$cmdline" == *"periodic-monitor.sh"* ]]; then
                # 第一阶段：TERM
                if ! kill -TERM "$pid" 2>/dev/null; then
                    log_debug "Failed to send TERM to monitor pid=$pid"
                fi

                # 等待最多 2 秒
                local wait_count=0
                while [[ -d "/proc/$pid" ]] && [[ $wait_count -lt 20 ]]; do
                    sleep 0.1
                    ((wait_count++))
                done

                # 第二阶段：KILL（如果仍存在）
                if [[ -d "/proc/$pid" ]]; then
                    if ! kill -KILL "$pid" 2>/dev/null; then
                        log_debug "Failed to send KILL to monitor pid=$pid"
                    fi
                fi
            else
                log_debug "PID $pid cmdline mismatch, not killing"
            fi
        fi
    fi

    rm -rf "$state_dir"
}

# Record task start / 记录任务开始
set_task_start() {
    local session_id="$1"
    local user_prompt="$2"
    local state_dir
    state_dir=$(init_state "$session_id")

    # Record start time / 记录开始时间
    atomic_write "${state_dir}/task-start-time" "$(date +%s)"

    # Record user input (truncated) / 记录用户输入（截断）
    local max_chars="${CC_NOTIFY_PROMPT_MAX_CHARS:-60}"
    local truncated_prompt
    if [[ ${#user_prompt} -gt $max_chars ]]; then
        truncated_prompt="${user_prompt:0:$max_chars}..."
    else
        truncated_prompt="$user_prompt"
    fi
    # Single line / 单行化
    truncated_prompt=$(echo "$truncated_prompt" | tr '\n' ' ' | tr -s ' ')
    atomic_write "${state_dir}/user-prompt" "$truncated_prompt"

    # Record tmux info / 记录 tmux 信息
    if [[ -n "$TMUX" ]]; then
        local tmux_session tmux_window tmux_pane
        tmux_session=$(tmux display-message -p '#{session_name}')
        tmux_window=$(tmux display-message -p '#{window_id}')
        tmux_pane=$(tmux display-message -p '#{pane_id}')
        atomic_write "${state_dir}/tmux-info" "${tmux_session}:${tmux_window}:${tmux_pane}"
    fi

    # Initialize periodic notification time / 初始化周期通知时间
    atomic_write "${state_dir}/last-periodic-time" "$(date +%s)"

    # Clear waiting state / 清除等待状态
    rm -f "${state_dir}/waiting-input"
}

# Get task start time / 获取任务开始时间
get_task_start_time() {
    local session_id="$1"
    local state_dir
    state_dir=$(get_state_dir "$session_id")

    if [[ -f "${state_dir}/task-start-time" ]]; then
        cat "${state_dir}/task-start-time"
    else
        echo "0"
    fi
}

# Get user prompt / 获取用户输入
get_user_prompt() {
    local session_id="$1"
    local state_dir
    state_dir=$(get_state_dir "$session_id")

    if [[ -f "${state_dir}/user-prompt" ]]; then
        cat "${state_dir}/user-prompt"
    else
        echo ""
    fi
}

# Get tmux info / 获取 tmux 信息
get_tmux_info() {
    local session_id="$1"
    local state_dir
    state_dir=$(get_state_dir "$session_id")

    if [[ -f "${state_dir}/tmux-info" ]]; then
        cat "${state_dir}/tmux-info"
    else
        echo ""
    fi
}

# Get tmux session name / 获取 tmux session 名称
get_tmux_session_name() {
    local session_id="$1"
    local tmux_info
    tmux_info=$(get_tmux_info "$session_id")
    echo "${tmux_info%%:*}"
}

# Set waiting input state / 设置等待输入状态
set_waiting_input() {
    local session_id="$1"
    local state_dir
    state_dir=$(get_state_dir "$session_id")
    touch "${state_dir}/waiting-input"
}

# Clear waiting input state / 清除等待输入状态
# 不再重置周期通知计时器，保持稳定的 5 分钟间隔
clear_waiting_input() {
    local session_id="$1"
    local state_dir
    state_dir=$(get_state_dir "$session_id")
    rm -f "${state_dir}/waiting-input"
}

# Check if waiting for input / 检查是否在等待输入状态
is_waiting_input() {
    local session_id="$1"
    local state_dir
    state_dir=$(get_state_dir "$session_id")
    [[ -f "${state_dir}/waiting-input" ]]
}

# Check if task is running / 检查任务是否在运行
is_task_running() {
    local session_id="$1"
    local state_dir
    state_dir=$(get_state_dir "$session_id")
    [[ -f "${state_dir}/task-start-time" ]]
}

# Get last periodic notification time / 获取上次周期通知时间
get_last_periodic_time() {
    local session_id="$1"
    local state_dir
    state_dir=$(get_state_dir "$session_id")

    if [[ -f "${state_dir}/last-periodic-time" ]]; then
        cat "${state_dir}/last-periodic-time"
    else
        echo "0"
    fi
}

# Update periodic notification time / 更新周期通知时间
update_last_periodic_time() {
    local session_id="$1"
    local state_dir
    state_dir=$(get_state_dir "$session_id")
    atomic_write "${state_dir}/last-periodic-time" "$(date +%s)"
}

# Save monitor process PID / 保存监控进程 PID
set_monitor_pid() {
    local session_id="$1"
    local pid="$2"
    local state_dir
    state_dir=$(get_state_dir "$session_id")
    atomic_write "${state_dir}/monitor.pid" "$pid"
}

# Get monitor process PID / 获取监控进程 PID
get_monitor_pid() {
    local session_id="$1"
    local state_dir
    state_dir=$(get_state_dir "$session_id")

    if [[ -f "${state_dir}/monitor.pid" ]]; then
        cat "${state_dir}/monitor.pid"
    else
        echo ""
    fi
}

# Save Windows Terminal window handle / 保存 Windows Terminal 窗口句柄
set_wt_hwnd() {
    local session_id="$1"
    local hwnd="$2"
    local state_dir
    state_dir=$(get_state_dir "$session_id")
    atomic_write "${state_dir}/wt-hwnd" "$hwnd"
}

# Get Windows Terminal window handle / 获取 Windows Terminal 窗口句柄
get_wt_hwnd() {
    local session_id="$1"
    local state_dir
    state_dir=$(get_state_dir "$session_id")
    [[ -f "${state_dir}/wt-hwnd" ]] && cat "${state_dir}/wt-hwnd"
}

# Calculate elapsed minutes / 计算已运行分钟数
get_elapsed_minutes() {
    local session_id="$1"
    local start_time
    start_time=$(get_task_start_time "$session_id")
    local now
    now=$(date +%s)
    echo $(( (now - start_time) / 60 ))
}
