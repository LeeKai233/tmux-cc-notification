#!/bin/bash
# on-task-start.sh - UserPromptSubmit hook
# Called when task starts: record state, start periodic notification monitor
# 任务开始时调用：记录状态，启动周期通知监控
# SEC-2026-0112-0409 H2/H3 修复：输入校验 + Add-Type 防护

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

# Load dependencies / 加载依赖
source "${BASE_DIR}/config.sh"
source "${BASE_DIR}/lib/state.sh"
source "${BASE_DIR}/lib/pwsh.sh"
source "${BASE_DIR}/lib/json.sh"
source "${BASE_DIR}/lib/log.sh"
source "${BASE_DIR}/lib/audit.sh" 2>/dev/null || true

load_all_config

# Read hook input / 读取 hook 输入
INPUT=$(cat)

# SEC-2026-0112-0409 M3：fail-fast JSON 校验
if ! validate_json "$INPUT"; then
    log_error "Invalid JSON input, aborting"
    exit 0
fi

# Parse session_id and prompt / 解析 session_id 和 prompt
SESSION_ID=$(parse_session_id "$INPUT")
USER_PROMPT=$(parse_prompt "$INPUT")

# 校验失败时退出
if [[ -z "$SESSION_ID" ]]; then
    exit 0
fi

log_debug "Task start: session=$SESSION_ID"

# Record task start / 记录任务开始
set_task_start "$SESSION_ID" "$USER_PROMPT"
audit_session_start "$SESSION_ID"

# Capture current active window handle / 捕获当前活动窗口的句柄
PWSH=$(find_pwsh)

if [[ -n "$PWSH" ]]; then
    # Capture HWND / 捕获 HWND
    # SEC-2026-0112-0409 H3 修复：使用单引号 here-string + 幂等加载
    HWND=$("$PWSH" -NoProfile -Command '
if (-not ("Win32HWND" -as [type])) {
    Add-Type -TypeDefinition @'"'"'
using System;
using System.Runtime.InteropServices;
public class Win32HWND { [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow(); }
'"'"'@ -ErrorAction SilentlyContinue
}
[Win32HWND]::GetForegroundWindow()
' 2>/dev/null | tr -d '\r')
    [[ -n "$HWND" ]] && set_wt_hwnd "$SESSION_ID" "$HWND"
fi

# If periodic notifications enabled, start background monitor / 如果周期通知启用，启动后台监控进程
if [[ "$CC_NOTIFY_RUNNING_ENABLED" == "1" ]]; then
    MONITOR_SCRIPT="${BASE_DIR}/lib/periodic-monitor.sh"

    # Kill any existing monitor process / 杀掉可能存在的旧监控进程
    OLD_PID=$(get_monitor_pid "$SESSION_ID")
    if [[ -n "$OLD_PID" ]]; then
        kill "$OLD_PID" 2>/dev/null
    fi

    # Start new monitor process / 启动新的监控进程
    nohup bash "$MONITOR_SCRIPT" "$SESSION_ID" > /dev/null 2>&1 &
    MONITOR_PID=$!

    # Save PID / 保存 PID
    set_monitor_pid "$SESSION_ID" "$MONITOR_PID"
    log_debug "Started monitor process: PID=$MONITOR_PID"
fi
