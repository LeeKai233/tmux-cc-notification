#!/usr/bin/env bash
# lib/validate.sh - 输入校验函数
# SEC-2026-0112-0409 H2 修复：路径遍历防护
# SEC-2026-0112-0409 P1-1：校验失败审计日志

# 加载审计模块（如果可用）
SCRIPT_DIR_VALIDATE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR_VALIDATE}/audit.sh" 2>/dev/null || true

# 校验 session_id 格式
# 仅允许 [A-Za-z0-9_-]，长度 <= 64
validate_session_id() {
    local session_id="$1"

    # 拒绝空值
    if [[ -z "$session_id" ]]; then
        echo "ERROR: session_id is empty" >&2
        audit_validation_failure "session_id" "empty" 2>/dev/null || true
        return 1
    fi

    # 拒绝包含路径分隔符或 ..
    if [[ "$session_id" == *".."* ]] || [[ "$session_id" == *"/"* ]] || [[ "$session_id" == *"\\"* ]]; then
        echo "ERROR: session_id contains invalid path characters" >&2
        audit_validation_failure "session_id" "path_traversal" 2>/dev/null || true
        return 1
    fi

    # 仅允许字母数字、连字符、下划线
    if [[ ! "$session_id" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "ERROR: session_id contains invalid characters" >&2
        audit_validation_failure "session_id" "invalid_chars" 2>/dev/null || true
        return 1
    fi

    # 长度限制
    if [[ ${#session_id} -gt 64 ]]; then
        echo "ERROR: session_id too long (max 64)" >&2
        audit_validation_failure "session_id" "too_long" 2>/dev/null || true
        return 1
    fi

    echo "$session_id"
}

# 校验路径在 base_dir 内
validate_path_in_base() {
    local path="$1"
    local base_dir="$2"

    # 规范化路径
    local real_path
    real_path=$(realpath -m "$path" 2>/dev/null) || return 1
    local real_base
    real_base=$(realpath -m "$base_dir" 2>/dev/null) || return 1

    # 断言路径以 base_dir 开头
    if [[ "$real_path" != "$real_base"/* ]] && [[ "$real_path" != "$real_base" ]]; then
        echo "ERROR: path escapes base directory" >&2
        return 1
    fi

    echo "$real_path"
}

# 校验 tmux pane 格式
# 允许：%数字、@数字、session:window.pane、纯字母数字
validate_tmux_pane() {
    local pane="$1"

    if [[ -z "$pane" ]]; then
        echo "ERROR: tmux pane is empty" >&2
        return 1
    fi

    # 仅允许安全的 tmux pane 格式
    if [[ "$pane" =~ ^[%@]?[0-9]+$ ]] || \
       [[ "$pane" =~ ^[a-zA-Z0-9_-]+:[0-9]+\.[0-9]+$ ]] || \
       [[ "$pane" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "$pane"
        return 0
    fi

    echo "ERROR: invalid tmux pane format" >&2
    return 1
}
