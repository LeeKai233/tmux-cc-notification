#!/bin/bash
# suppress.sh - Notification suppression logic / 通知抑制逻辑模块
# Check if notification should be suppressed (user is viewing the pane)

_SUPPRESS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_SUPPRESS_SCRIPT_DIR}/pwsh.sh"
source "${_SUPPRESS_SCRIPT_DIR}/log.sh"

# Check if Windows Terminal is foreground window / 检查 Windows Terminal 是否为前台窗口
is_windows_terminal_foreground() {
    local pwsh
    pwsh=$(find_pwsh) || return 1

    local result
    result=$("$pwsh" -NoProfile -Command '
        Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public class ForegroundWindow {
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
}
"@
        $hwnd = [ForegroundWindow]::GetForegroundWindow()
        $processId = 0
        [ForegroundWindow]::GetWindowThreadProcessId($hwnd, [ref]$processId) | Out-Null
        try {
            $proc = Get-Process -Id $processId -ErrorAction Stop
            if ($proc.ProcessName -eq "WindowsTerminal") { "1" } else { "0" }
        } catch { "0" }
    ' 2>/dev/null | tr -d '\r')

    [[ "$result" == "1" ]]
}

# Get active client info (most recently active) / 获取活跃客户端信息
# Returns: session_name:window_id:pane_id
get_active_client_info() {
    tmux list-clients -F '#{client_activity}:#{session_name}:#{window_id}:#{pane_id}' 2>/dev/null \
        | sort -t: -k1 -rn \
        | head -1 \
        | cut -d: -f2-
}

# Check if current tmux window is target window / 检查当前 tmux window 是否为目标 window
is_target_window_visible() {
    local target_window="$1"

    if [[ -z "$TMUX" ]]; then
        return 1
    fi

    # Get current active window / 获取当前活动 window
    local current_window
    current_window=$(tmux display-message -p '#{window_id}' 2>/dev/null)

    [[ "$current_window" == "$target_window" ]]
}

# Check if target pane is visible (considering zoom state) / 检查目标 pane 是否可见（考虑 zoom 状态）
is_target_pane_visible() {
    local target_pane="$1"

    if [[ -z "$TMUX" ]]; then
        return 1
    fi

    # Check if current window is zoomed / 检查当前 window 是否 zoomed
    local is_zoomed
    is_zoomed=$(tmux display-message -p '#{window_zoomed_flag}' 2>/dev/null)

    if [[ "$is_zoomed" == "1" ]]; then
        # If zoomed, only active pane is visible / 如果 zoomed，只有 active pane 可见
        local active_pane
        active_pane=$(tmux display-message -p '#{pane_id}' 2>/dev/null)
        [[ "$active_pane" == "$target_pane" ]]
    else
        # Not zoomed, check if pane is in current window / 非 zoomed，检查 pane 是否在当前 window
        local pane_window
        pane_window=$(tmux display-message -t "$target_pane" -p '#{window_id}' 2>/dev/null)
        local current_window
        current_window=$(tmux display-message -p '#{window_id}' 2>/dev/null)
        [[ "$pane_window" == "$current_window" ]]
    fi
}

# Main suppression check function / 主抑制检查函数
# Args: session_id [notify_type]
# notify_type: need_input, running, done (optional)
# Returns: 0 = should suppress, 1 = don't suppress
should_suppress() {
    local session_id="$1"
    local notify_type="${2:-}"

    # Check per-stage suppress config / 检查分阶段抑制配置
    case "$notify_type" in
        need_input)
            if [[ "${CC_NOTIFY_SUPPRESS_NEED_INPUT:-1}" != "1" ]]; then
                log_debug "suppress: need_input disabled"
                return 1
            fi ;;
        running)
            if [[ "${CC_NOTIFY_SUPPRESS_RUNNING:-1}" != "1" ]]; then
                log_debug "suppress: running disabled"
                return 1
            fi ;;
        done)
            if [[ "${CC_NOTIFY_SUPPRESS_DONE:-1}" != "1" ]]; then
                log_debug "suppress: done disabled"
                return 1
            fi ;;
        *)
            if [[ "${CC_NOTIFY_SUPPRESS_ENABLED:-1}" != "1" ]]; then
                log_debug "suppress: globally disabled"
                return 1
            fi ;;
    esac

    # Check if Windows Terminal is foreground / 检查 Windows Terminal 是否前台
    if ! is_windows_terminal_foreground; then
        log_debug "suppress: WT not foreground"
        return 1
    fi

    # Get target tmux info / 获取目标 tmux 信息
    source "${_SUPPRESS_SCRIPT_DIR}/state.sh"
    local tmux_info
    tmux_info=$(get_tmux_info "$session_id")

    if [[ -z "$tmux_info" ]]; then
        log_debug "suppress: no tmux info"
        return 1
    fi

    # Parse tmux info: session:window:pane / 解析 tmux 信息
    local target_session target_window target_pane
    IFS=':' read -r target_session target_window target_pane <<< "$tmux_info"

    # Get active client info / 获取活跃客户端信息
    local client_info
    client_info=$(get_active_client_info)

    if [[ -z "$client_info" ]]; then
        log_debug "suppress: no active client"
        return 1
    fi

    local current_session current_window current_pane
    IFS=':' read -r current_session current_window current_pane <<< "$client_info"

    log_debug "suppress: target=$target_session:$target_window:$target_pane current=$current_session:$current_window:$current_pane"

    # Check if currently in target session / 检查当前是否在目标 session
    if [[ "$current_session" != "$target_session" ]]; then
        log_debug "suppress: session mismatch"
        return 1
    fi

    # Check if target window is visible / 检查目标 window 是否可见
    if [[ "$current_window" != "$target_window" ]]; then
        log_debug "suppress: window mismatch"
        return 1
    fi

    # Check zoom state / 检查 zoom 状态
    local is_zoomed
    is_zoomed=$(tmux display-message -t "$target_pane" -p '#{window_zoomed_flag}' 2>/dev/null)

    if [[ "$is_zoomed" == "1" ]]; then
        # If zoomed, only active pane is visible / 如果 zoomed，只有 active pane 可见
        if [[ "$current_pane" != "$target_pane" ]]; then
            log_debug "suppress: zoomed, pane mismatch"
            return 1
        fi
    fi

    log_debug "suppress: YES"
    return 0  # Should suppress / 应该抑制
}
