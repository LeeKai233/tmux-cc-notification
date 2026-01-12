#!/bin/bash
# suppress.sh - Notification suppression logic / 通知抑制逻辑模块
# Check if notification should be suppressed (user is viewing the pane)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/pwsh.sh"

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
    ' 2>/dev/null)

    [[ "$result" == "1" ]]
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
# Args: session_id
# Returns: 0 = should suppress, 1 = don't suppress
should_suppress() {
    local session_id="$1"

    # Check if suppression is enabled / 检查抑制是否启用
    if [[ "${CC_NOTIFY_SUPPRESS_ENABLED:-1}" != "1" ]]; then
        return 1
    fi

    # Check if Windows Terminal is foreground / 检查 Windows Terminal 是否前台
    if ! is_windows_terminal_foreground; then
        return 1
    fi

    # Get target tmux info / 获取目标 tmux 信息
    source "${SCRIPT_DIR}/state.sh"
    local tmux_info
    tmux_info=$(get_tmux_info "$session_id")

    if [[ -z "$tmux_info" ]]; then
        return 1
    fi

    # Parse tmux info: session:window:pane / 解析 tmux 信息
    local target_session target_window target_pane
    IFS=':' read -r target_session target_window target_pane <<< "$tmux_info"

    # Check if currently in target session / 检查当前是否在目标 session
    local current_session
    current_session=$(tmux display-message -p '#{session_name}' 2>/dev/null)

    if [[ "$current_session" != "$target_session" ]]; then
        return 1
    fi

    # Check if target pane is visible / 检查目标 pane 是否可见
    if is_target_pane_visible "$target_pane"; then
        return 0  # Should suppress / 应该抑制
    fi

    return 1  # Don't suppress / 不抑制
}
