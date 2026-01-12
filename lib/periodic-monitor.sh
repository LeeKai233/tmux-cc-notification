#!/bin/bash
# periodic-monitor.sh - Periodic notification background monitor
# 周期通知后台监控进程 - 在后台运行，定期检查并发送进行中通知
# SEC-2026-0112-0409 H1/H2/M5 修复：输入校验 + Base64 安全传参 + 信号处理

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

# Load dependencies / 加载依赖模块
LIB_DIR="$SCRIPT_DIR"  # 保存 lib 目录路径（config.sh 会覆盖 SCRIPT_DIR）
source "${BASE_DIR}/config.sh"
source "${LIB_DIR}/state.sh"
source "${LIB_DIR}/suppress.sh"
source "${LIB_DIR}/pwsh.sh"
source "${LIB_DIR}/log.sh"
source "${LIB_DIR}/sanitize.sh"
source "${LIB_DIR}/validate.sh"

load_all_config

SESSION_ID="$1"

# SEC-2026-0112-0409 H2 修复：校验 session_id
SESSION_ID=$(validate_session_id "$SESSION_ID") || exit 1

# SEC-2026-0112-0409 M5：信号处理 - 收到 TERM/INT 时清理退出
cleanup_on_exit() {
    local state_dir
    state_dir=$(get_state_dir "$SESSION_ID" 2>/dev/null)
    [[ -f "${state_dir}/monitor.pid" ]] && rm -f "${state_dir}/monitor.pid"
    exit 0
}
trap cleanup_on_exit TERM INT

PWSH=$(find_pwsh)
PS_SCRIPT="${BASE_DIR}/ps/send-toast.ps1"
CHECK_INTERVAL=30  # Check interval in seconds / 检查间隔（秒）

if [[ -z "$SESSION_ID" ]]; then
    exit 1
fi

# Convert WSL path to Windows path / 转换 WSL 路径为 Windows 路径
WIN_PS_SCRIPT=$(wslpath -w "$PS_SCRIPT" 2>/dev/null || echo "$PS_SCRIPT")

# Check PowerShell availability / 检查 PowerShell 可用性
if [[ -z "$PWSH" ]]; then
    exit 1
fi

send_periodic_notification() {
    local elapsed_minutes
    elapsed_minutes=$(get_elapsed_minutes "$SESSION_ID")
    # Round down to nearest interval multiple / 向下取整到通知间隔的整数倍
    local minutes=$(( (elapsed_minutes / CC_NOTIFY_RUNNING_INTERVAL) * CC_NOTIFY_RUNNING_INTERVAL ))

    local user_prompt
    user_prompt=$(get_user_prompt "$SESSION_ID")

    local session_name
    session_name=$(get_tmux_session_name "$SESSION_ID")

    # Build TmuxInfo: pane_id:hwnd / 构建 TmuxInfo
    local tmux_pane
    tmux_pane=$(tmux display-message -p '#{pane_id}' 2>/dev/null)
    local hwnd
    hwnd=$(get_wt_hwnd "$SESSION_ID")
    local tmux_info="${tmux_pane}:${hwnd}"

    # Build title and body / 构建标题和正文
    local title="${CC_NOTIFY_TITLE_TPL//\{session\}/$session_name}"
    local body="${CC_NOTIFY_RUNNING_BODY_TPL//\{mm\}/$minutes}"
    body="${body//\{prompt\}/$user_prompt}"

    # SEC-2026-0112-0409 H1 修复：使用 Base64 安全传参
    local title_b64
    title_b64=$(safe_encode_for_pwsh "$title" 100)
    local body_b64
    body_b64=$(safe_encode_for_pwsh "$body" 200)
    local tmux_info_b64
    tmux_info_b64=$(to_base64 "$tmux_info")

    # SEC-2026-0112-0409 M2：使用配置的执行策略
    local exec_policy
    exec_policy=$(get_execution_policy)

    # Call PowerShell to send notification / 调用 PowerShell 发送通知
    "$PWSH" -NoProfile -ExecutionPolicy "$exec_policy" -File "$WIN_PS_SCRIPT" \
        -Type "running" \
        -SessionId "$SESSION_ID" \
        -TitleB64 "$title_b64" \
        -BodyB64 "$body_b64" \
        -AppLogo "$CC_NOTIFY_APP_LOGO" \
        -SoundPath "$CC_NOTIFY_RUNNING_SOUND" \
        -SoundRepeat "$CC_NOTIFY_RUNNING_SOUND_REPEAT" \
        -UpdateSame "$CC_NOTIFY_RUNNING_UPDATE_SAME" \
        -TmuxInfoB64 "$tmux_info_b64" \
        2>/dev/null
}

# Main loop function / 主循环函数
main_loop() {
    while true; do
        sleep "$CHECK_INTERVAL"

        # Check if task is still running / 检查任务是否还在运行
        if ! is_task_running "$SESSION_ID"; then
            break
        fi

        # Check if Claude Code process is still running / 检查进程是否还在运行
        if ! pgrep -f "(claude|kiro-cli)" >/dev/null 2>&1; then
            cleanup_state "$SESSION_ID"
            break
        fi

        # Check if waiting for input / 检查是否在等待输入状态
        if is_waiting_input "$SESSION_ID"; then
            continue
        fi

        # Check if should suppress / 检查是否应该抑制
        if should_suppress "$SESSION_ID" "running"; then
            continue
        fi

        # Check if notification interval reached / 检查是否到达通知间隔
        local last_time
        last_time=$(get_last_periodic_time "$SESSION_ID")
        local now
        now=$(date +%s)
        local interval_seconds=$((CC_NOTIFY_RUNNING_INTERVAL * 60))

        # Check if task is idle (no tool use for 60 seconds) / 检查任务是否空闲
        local last_tool_time
        last_tool_time=$(get_last_tool_time "$SESSION_ID")
        local idle_threshold=60
        if (( now - last_tool_time > idle_threshold )); then
            continue  # Skip notification if idle
        fi

        if (( now - last_time >= interval_seconds )); then
            send_periodic_notification
            update_last_periodic_time "$SESSION_ID"
        fi
    done
}

main_loop
