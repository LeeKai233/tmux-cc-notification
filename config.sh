#!/bin/bash
# config.sh - TOML configuration loader / TOML 配置加载模块
# Provides configuration reading functions with defaults

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/.tmux_cc_notify_conf.toml"

# Source constants / 加载常量
source "${SCRIPT_DIR}/lib/constants.sh" 2>/dev/null || true

# Simple TOML parser: get value for key in section
# 简单 TOML 解析：获取指定 section 下的 key 值
# Usage: get_config "section" "key" "default_value"
get_config() {
    local section="$1"
    local key="$2"
    local default="$3"

    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "$default"
        return
    fi

    local in_section=0
    local value=""

    while IFS= read -r line || [[ -n "$line" ]]; do
        # 去除首尾空白
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"

        # 跳过空行和注释
        [[ -z "$line" || "$line" == \#* ]] && continue

        # 检查 section 头
        if [[ "$line" =~ ^\[([a-zA-Z_]+)\]$ ]]; then
            if [[ "${BASH_REMATCH[1]}" == "$section" ]]; then
                in_section=1
            else
                in_section=0
            fi
            continue
        fi

        # 在目标 section 内查找 key
        if [[ $in_section -eq 1 && "$line" =~ ^${key}[[:space:]]*=[[:space:]]*(.+)$ ]]; then
            value="${BASH_REMATCH[1]}"
            # 去除行内注释 (# 后面的内容)
            value="${value%%#*}"
            # 去除尾部空白
            value="${value%"${value##*[![:space:]]}"}"
            # 去除引号
            value="${value#\"}"
            value="${value%\"}"
            value="${value#\'}"
            value="${value%\'}"
            break
        fi
    done < "$CONFIG_FILE"

    if [[ -n "$value" ]]; then
        # 处理 TOML 转义字符: \\ -> \
        value="${value//\\\\/\\}"
        echo "$value"
    else
        echo "$default"
    fi
}

# Get boolean config / 获取布尔配置
get_config_bool() {
    local section="$1"
    local key="$2"
    local default="$3"

    local value
    value=$(get_config "$section" "$key" "$default")

    case "$value" in
        true|True|TRUE|1|yes|Yes|YES) echo "1" ;;
        *) echo "0" ;;
    esac
}

# Get integer config / 获取整数配置
get_config_int() {
    local section="$1"
    local key="$2"
    local default="$3"

    local value
    value=$(get_config "$section" "$key" "$default")

    if [[ "$value" =~ ^[0-9]+$ ]]; then
        echo "$value"
    else
        echo "$default"
    fi
}

# Preload common config to environment variables / 预加载常用配置到环境变量
load_all_config() {
    # Assets (empty defaults - user should configure) / 资源（空默认值 - 用户需配置）
    export CC_NOTIFY_APP_LOGO
    CC_NOTIFY_APP_LOGO=$(get_config "assets" "app_logo" '')
    export CC_NOTIFY_HERO_IMAGE
    CC_NOTIFY_HERO_IMAGE=$(get_config "assets" "hero_image_task_end" '')

    # Text / 文本
    export CC_NOTIFY_TITLE_TPL
    CC_NOTIFY_TITLE_TPL=$(get_config "text" "title" '{session} Claude Code')
    export CC_NOTIFY_RUNNING_BODY_TPL
    CC_NOTIFY_RUNNING_BODY_TPL=$(get_config "text" "running_body" '[Running: {mm} min] {prompt}')
    export CC_NOTIFY_DONE_BODY_TPL
    CC_NOTIFY_DONE_BODY_TPL=$(get_config "text" "done_body" '[Total: {mm} min] {prompt}')
    export CC_NOTIFY_NEED_INPUT_BODY
    CC_NOTIFY_NEED_INPUT_BODY=$(get_config "text" "need_input_body" 'Permission/input required')
    export CC_NOTIFY_PROMPT_MAX_CHARS
    CC_NOTIFY_PROMPT_MAX_CHARS=$(get_config_int "text" "prompt_max_chars" "${DEFAULT_PROMPT_MAX_CHARS:-60}")

    # Running / 运行中通知
    export CC_NOTIFY_RUNNING_ENABLED
    CC_NOTIFY_RUNNING_ENABLED=$(get_config_bool "running" "enabled" "1")
    export CC_NOTIFY_RUNNING_INTERVAL
    CC_NOTIFY_RUNNING_INTERVAL=$(get_config_int "running" "interval_minutes" "${DEFAULT_RUNNING_INTERVAL:-5}")
    export CC_NOTIFY_RUNNING_SOUND
    CC_NOTIFY_RUNNING_SOUND=$(get_config "running" "sound_path" "${DEFAULT_SOUND_RUNNING:-C:\\Windows\\Media\\chimes.wav}")
    export CC_NOTIFY_RUNNING_SOUND_REPEAT
    CC_NOTIFY_RUNNING_SOUND_REPEAT=$(get_config_int "running" "sound_repeat" "1")
    export CC_NOTIFY_RUNNING_UPDATE_SAME
    CC_NOTIFY_RUNNING_UPDATE_SAME=$(get_config_bool "running" "update_same_toast" "1")

    # Need Input / 需要输入通知
    export CC_NOTIFY_NEED_INPUT_ENABLED
    CC_NOTIFY_NEED_INPUT_ENABLED=$(get_config_bool "need_input" "enabled" "1")
    export CC_NOTIFY_NEED_INPUT_SOUND
    CC_NOTIFY_NEED_INPUT_SOUND=$(get_config "need_input" "sound_path" "${DEFAULT_SOUND_INPUT:-C:\\Windows\\Media\\notify.wav}")
    export CC_NOTIFY_NEED_INPUT_SOUND_REPEAT
    CC_NOTIFY_NEED_INPUT_SOUND_REPEAT=$(get_config_int "need_input" "sound_repeat" "2")

    # Done / 完成通知
    export CC_NOTIFY_DONE_ENABLED
    CC_NOTIFY_DONE_ENABLED=$(get_config_bool "done" "enabled" "1")
    export CC_NOTIFY_DONE_SOUND
    CC_NOTIFY_DONE_SOUND=$(get_config "done" "sound_path" "${DEFAULT_SOUND_DONE:-C:\\Windows\\Media\\tada.wav}")
    export CC_NOTIFY_DONE_SOUND_REPEAT
    CC_NOTIFY_DONE_SOUND_REPEAT=$(get_config_int "done" "sound_repeat" "1")

    # Suppress / 抑制
    export CC_NOTIFY_SUPPRESS_ENABLED
    CC_NOTIFY_SUPPRESS_ENABLED=$(get_config_bool "suppress" "enabled" "1")

    # Suppress per-stage / 分阶段抑制配置
    export CC_NOTIFY_SUPPRESS_NEED_INPUT
    CC_NOTIFY_SUPPRESS_NEED_INPUT=$(get_config_bool "suppress" "need_input" "1")
    export CC_NOTIFY_SUPPRESS_RUNNING
    CC_NOTIFY_SUPPRESS_RUNNING=$(get_config_bool "suppress" "running" "1")
    export CC_NOTIFY_SUPPRESS_DONE
    CC_NOTIFY_SUPPRESS_DONE=$(get_config_bool "suppress" "done" "1")

    # SEC-2026-0112-0409 M2：PowerShell 执行策略配置
    # 默认 RemoteSigned，用户可设置为 Bypass（需显式 opt-in）
    export CC_NOTIFY_PWSH_EXECUTION_POLICY
    CC_NOTIFY_PWSH_EXECUTION_POLICY=$(get_config "security" "pwsh_execution_policy" "RemoteSigned")

    # SEC-2026-0112-0409 L2：PowerShell 可执行文件路径（可选）
    export CC_NOTIFY_PWSH_PATH
    CC_NOTIFY_PWSH_PATH=$(get_config "system" "pwsh_path" "")

    # SEC-2026-0112-0409 L3：配置值边界校验
    validate_config_bounds
}

# SEC-2026-0112-0409 L3：配置值边界约束
validate_config_bounds() {
    # prompt_max_chars: 10-500
    if [[ "$CC_NOTIFY_PROMPT_MAX_CHARS" -lt 10 ]]; then
        CC_NOTIFY_PROMPT_MAX_CHARS=10
    elif [[ "$CC_NOTIFY_PROMPT_MAX_CHARS" -gt 500 ]]; then
        CC_NOTIFY_PROMPT_MAX_CHARS=500
    fi

    # running_interval: 1-60 分钟
    if [[ "$CC_NOTIFY_RUNNING_INTERVAL" -lt 1 ]]; then
        CC_NOTIFY_RUNNING_INTERVAL=1
    elif [[ "$CC_NOTIFY_RUNNING_INTERVAL" -gt 60 ]]; then
        CC_NOTIFY_RUNNING_INTERVAL=60
    fi

    # sound_repeat: 1-10
    if [[ "$CC_NOTIFY_RUNNING_SOUND_REPEAT" -lt 1 ]]; then
        CC_NOTIFY_RUNNING_SOUND_REPEAT=1
    elif [[ "$CC_NOTIFY_RUNNING_SOUND_REPEAT" -gt 10 ]]; then
        CC_NOTIFY_RUNNING_SOUND_REPEAT=10
    fi

    if [[ "$CC_NOTIFY_NEED_INPUT_SOUND_REPEAT" -lt 1 ]]; then
        CC_NOTIFY_NEED_INPUT_SOUND_REPEAT=1
    elif [[ "$CC_NOTIFY_NEED_INPUT_SOUND_REPEAT" -gt 10 ]]; then
        CC_NOTIFY_NEED_INPUT_SOUND_REPEAT=10
    fi

    if [[ "$CC_NOTIFY_DONE_SOUND_REPEAT" -lt 1 ]]; then
        CC_NOTIFY_DONE_SOUND_REPEAT=1
    elif [[ "$CC_NOTIFY_DONE_SOUND_REPEAT" -gt 10 ]]; then
        CC_NOTIFY_DONE_SOUND_REPEAT=10
    fi
}
