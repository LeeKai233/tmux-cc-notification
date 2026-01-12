#!/bin/bash
# audit.sh - 安全审计日志
# SEC-2026-0112-0409 P1-1：独立于 debug 开关的安全事件日志

# Use XDG state dir for persistent audit logs
_CC_NOTIFY_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/cc-notify"
CC_NOTIFY_AUDIT_LOG="${CC_NOTIFY_AUDIT_LOG:-$_CC_NOTIFY_STATE_DIR/audit.log}"
CC_NOTIFY_AUDIT_ENABLED="${CC_NOTIFY_AUDIT_ENABLED:-1}"

# 审计日志初始化标志
_CC_NOTIFY_AUDIT_INITIALIZED=0

# 初始化审计日志
init_audit() {
    [[ "$CC_NOTIFY_AUDIT_ENABLED" != "1" ]] && return 0
    [[ "$_CC_NOTIFY_AUDIT_INITIALIZED" == "1" ]] && return 0

    # Create state directory if needed
    local audit_dir
    audit_dir=$(dirname "$CC_NOTIFY_AUDIT_LOG")
    [[ ! -d "$audit_dir" ]] && mkdir -p "$audit_dir" && chmod 700 "$audit_dir"

    touch "$CC_NOTIFY_AUDIT_LOG" 2>/dev/null
    chmod 600 "$CC_NOTIFY_AUDIT_LOG" 2>/dev/null

    _CC_NOTIFY_AUDIT_INITIALIZED=1
}

# 写入审计事件（JSONL 格式）
audit_log() {
    [[ "$CC_NOTIFY_AUDIT_ENABLED" != "1" ]] && return 0
    init_audit

    local event="$1"
    local details="$2"
    local timestamp
    timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

    # 截断 details 防止日志注入（最大 256 字符）
    details="${details:0:256}"
    # 转义双引号
    details="${details//\"/\\\"}"
    # 控制字符归一化为空格
    details=$(printf '%s' "$details" | tr '\n\r\t' '   ')

    printf '{"ts":"%s","event":"%s","details":"%s","pid":%d}\n' \
        "$timestamp" "$event" "$details" "$$" >> "$CC_NOTIFY_AUDIT_LOG"
}

# 会话开始
audit_session_start() {
    local session_id="$1"
    # 只记录 session_id 前 16 字符（隐私保护）
    audit_log "SESSION_START" "session=${session_id:0:16}"
}

# 会话结束
audit_session_end() {
    local session_id="$1"
    audit_log "SESSION_END" "session=${session_id:0:16}"
}

# 校验失败
audit_validation_failure() {
    local field="$1"
    local reason="$2"
    audit_log "VALIDATION_FAIL" "field=$field,reason=$reason"
}

# 通知发送
audit_notification_sent() {
    local type="$1"
    audit_log "NOTIFY_SENT" "type=$type"
}

# 限速触发
audit_rate_limited() {
    local session_id="$1"
    audit_log "RATE_LIMITED" "session=${session_id:0:16}"
}

# 权限异常
audit_permission_denied() {
    local operation="$1"
    local resource="$2"
    audit_log "PERMISSION_DENIED" "op=$operation,res=$resource"
}
