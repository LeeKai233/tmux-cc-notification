#!/bin/bash
# on-task-end.sh - Stop hook
# Called when task ends: send completion notification, cleanup state
# 任务结束时调用：发送完成通知，清理状态
# SEC-2026-0112-0409 H1/H2 修复：输入校验 + Base64 安全传参

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

# Load dependencies / 加载依赖
source "${BASE_DIR}/config.sh"
source "${BASE_DIR}/lib/state.sh"
source "${BASE_DIR}/lib/suppress.sh"
source "${BASE_DIR}/lib/pwsh.sh"
source "${BASE_DIR}/lib/json.sh"
source "${BASE_DIR}/lib/log.sh"
source "${BASE_DIR}/lib/sanitize.sh"
source "${BASE_DIR}/lib/audit.sh" 2>/dev/null || true

load_all_config

# Read hook input / 读取 hook 输入
INPUT=$(cat)

# SEC-2026-0112-0409 M3：fail-fast JSON 校验
if ! validate_json "$INPUT"; then
    log_error "Invalid JSON input, aborting"
    exit 0
fi

# Parse session_id / 解析 session_id
SESSION_ID=$(parse_session_id "$INPUT")

# 校验失败时退出
if [[ -z "$SESSION_ID" ]]; then
    exit 0
fi

# Check if task is running / 检查任务是否在运行
if ! is_task_running "$SESSION_ID"; then
    exit 0
fi

log_debug "Task end: session=$SESSION_ID"

# Get task info / 获取任务信息
ELAPSED_MINUTES=$(get_elapsed_minutes "$SESSION_ID")
USER_PROMPT=$(get_user_prompt "$SESSION_ID")
SESSION_NAME=$(get_tmux_session_name "$SESSION_ID")

# Build TmuxInfo: pane_id:hwnd / 构建 TmuxInfo
TMUX_PANE=$(tmux display-message -p '#{pane_id}' 2>/dev/null)
HWND=$(get_wt_hwnd "$SESSION_ID")
TMUX_INFO="${TMUX_PANE}:${HWND}"

# Send completion notification (if enabled) / 发送完成通知（如果启用）
if [[ "$CC_NOTIFY_DONE_ENABLED" == "1" ]]; then
    # Check if should suppress / 检查是否应该抑制
    if should_suppress "$SESSION_ID" "done"; then
        log_debug "Done notification suppressed (user viewing pane)"
    else
        PWSH=$(find_pwsh)
        PS_SCRIPT="${BASE_DIR}/ps/send-toast.ps1"
        WIN_PS_SCRIPT=$(wslpath -w "$PS_SCRIPT" 2>/dev/null || echo "$PS_SCRIPT")

        TITLE="${CC_NOTIFY_TITLE_TPL//\{session\}/$SESSION_NAME}"
        BODY="${CC_NOTIFY_DONE_BODY_TPL//\{mm\}/$ELAPSED_MINUTES}"
        BODY="${BODY//\{prompt\}/$USER_PROMPT}"

        # SEC-2026-0112-0409 H1 修复：使用 Base64 安全传参
        TITLE_B64=$(safe_encode_for_pwsh "$TITLE" 100)
        BODY_B64=$(safe_encode_for_pwsh "$BODY" 200)
        TMUX_INFO_B64=$(to_base64 "$TMUX_INFO")

        # SEC-2026-0112-0409 M2：使用配置的执行策略
        EXEC_POLICY=$(get_execution_policy)

        "$PWSH" -NoProfile -ExecutionPolicy "$EXEC_POLICY" -File "$WIN_PS_SCRIPT" \
            -Type "done" \
            -SessionId "$SESSION_ID" \
            -TitleB64 "$TITLE_B64" \
            -BodyB64 "$BODY_B64" \
            -AppLogo "$CC_NOTIFY_APP_LOGO" \
            -HeroImage "$CC_NOTIFY_HERO_IMAGE" \
            -SoundPath "$CC_NOTIFY_DONE_SOUND" \
            -SoundRepeat "$CC_NOTIFY_DONE_SOUND_REPEAT" \
            -TmuxInfoB64 "$TMUX_INFO_B64" \
            2>/dev/null

        log_debug "Sent done notification"
    fi
fi

# Cleanup state / 清理状态
audit_session_end "$SESSION_ID"
cleanup_state "$SESSION_ID"
log_debug "Cleaned up state"
