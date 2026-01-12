#!/bin/bash
# notify.sh - Unified notification sender / 统一通知发送模块
# Consolidates notification logic from multiple hooks

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

source "${SCRIPT_DIR}/pwsh.sh"
source "${SCRIPT_DIR}/log.sh"

# Send notification via PowerShell / 通过 PowerShell 发送通知
# Usage: send_notification TYPE SESSION_ID TITLE BODY [OPTIONS...]
# Options: -logo PATH -hero PATH -sound PATH -repeat N -update 0|1 -tmux INFO
send_notification() {
    local type="$1"
    local session_id="$2"
    local title="$3"
    local body="$4"
    shift 4

    # Parse optional arguments / 解析可选参数
    local app_logo="" hero_image="" sound_path="" sound_repeat="1" update_same="1" tmux_info=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -logo)    app_logo="$2"; shift 2 ;;
            -hero)    hero_image="$2"; shift 2 ;;
            -sound)   sound_path="$2"; shift 2 ;;
            -repeat)  sound_repeat="$2"; shift 2 ;;
            -update)  update_same="$2"; shift 2 ;;
            -tmux)    tmux_info="$2"; shift 2 ;;
            *)        shift ;;
        esac
    done

    # Get PowerShell path / 获取 PowerShell 路径
    local pwsh
    pwsh=$(find_pwsh)
    if [[ -z "$pwsh" ]]; then
        log_error "PowerShell not found, cannot send notification"
        return 1
    fi

    # Convert script path to Windows path / 转换脚本路径为 Windows 路径
    local ps_script="${BASE_DIR}/ps/send-toast.ps1"
    local win_ps_script
    win_ps_script=$(wslpath -w "$ps_script" 2>/dev/null || echo "$ps_script")

    log_debug "Sending notification: type=$type session=$session_id"

    # Build PowerShell arguments / 构建 PowerShell 参数
    # SEC-2026-0112-0409 M2：使用配置的执行策略
    local exec_policy
    exec_policy=$(get_execution_policy)

    local args=(
        -NoProfile
        -ExecutionPolicy "$exec_policy"
        -File "$win_ps_script"
        -Type "$type"
        -SessionId "$session_id"
        -Title "$title"
        -Body "$body"
    )

    [[ -n "$app_logo" ]] && args+=(-AppLogo "$app_logo")
    [[ -n "$hero_image" ]] && args+=(-HeroImage "$hero_image")
    [[ -n "$sound_path" ]] && args+=(-SoundPath "$sound_path")
    [[ -n "$sound_repeat" ]] && args+=(-SoundRepeat "$sound_repeat")
    [[ -n "$update_same" ]] && args+=(-UpdateSame "$update_same")
    [[ -n "$tmux_info" ]] && args+=(-TmuxInfo "$tmux_info")

    # Execute PowerShell / 执行 PowerShell
    # SEC-2026-0112-0409 L4：debug 模式下捕获 stderr
    local result
    if [[ "$CC_NOTIFY_DEBUG" == "1" ]]; then
        local stderr_out
        stderr_out=$("$pwsh" "${args[@]}" 2>&1)
        result=$?
        [[ -n "$stderr_out" ]] && log_debug "PowerShell output: $stderr_out"
    else
        "$pwsh" "${args[@]}" 2>/dev/null
        result=$?
    fi

    if [[ $result -ne 0 ]]; then
        log_error "Failed to send notification (exit code: $result)"
    fi

    return $result
}

# Build tmux info string for click-to-focus / 构建 tmux 信息字符串用于点击跳转
# Usage: build_tmux_info SESSION_ID
build_tmux_info() {
    local session_id="$1"

    # Get current pane ID / 获取当前 pane ID
    local tmux_pane
    tmux_pane=$(tmux display-message -p '#{pane_id}' 2>/dev/null)

    # Get stored window handle / 获取存储的窗口句柄
    local state_dir="${STATE_BASE_DIR:-/tmp/cc-notify}-${session_id}"
    local hwnd=""
    [[ -f "${state_dir}/wt-hwnd" ]] && hwnd=$(cat "${state_dir}/wt-hwnd")

    echo "${tmux_pane}:${hwnd}"
}
