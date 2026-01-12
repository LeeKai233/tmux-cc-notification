#!/bin/bash
# setup-hooks.sh - Auto-configure Claude Code hooks
# 自动配置 Claude Code 钩子到 ~/.claude/settings.json

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
HOOKS_DIR="${BASE_DIR}/hooks"
SETTINGS_FILE="$HOME/.claude/settings.json"
BACKUP_FILE="$HOME/.claude/settings.json.bak"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Detect language (use inherited LANG_CODE if available)
# Also check Windows locale via PowerShell in WSL environment
detect_lang() {
    local lang="${LC_ALL:-${LC_MESSAGES:-${LANG:-en}}}"
    case "$lang" in
        zh_*|ja_*|ko_*) echo "zh"; return ;;
    esac
    if command -v powershell.exe &>/dev/null; then
        local win_locale
        win_locale=$(powershell.exe -NoProfile -Command '(Get-WinSystemLocale).Name' 2>/dev/null | tr -d '\r')
        case "$win_locale" in
            zh-*|ja-*|ko-*) echo "zh"; return ;;
        esac
    fi
    echo "en"
}

if [[ -z "$LANG_CODE" ]]; then
    LANG_CODE=$(detect_lang)
fi

# Messages
if [[ "$LANG_CODE" == "zh" ]]; then
    MSG_USING_JQ="使用 jq 合并 JSON"
    MSG_BACKED_UP="已备份现有设置到"
    MSG_MERGED="已合并 hooks 到现有设置"
    MSG_CREATED="已创建新设置文件"
    MSG_SUCCESS="Claude Code 钩子配置成功！"
    MSG_NO_JQ="未找到 jq，使用回退方案"
    MSG_INSERTED="已插入 hooks 到设置"
    MSG_INSERT_FAILED="自动插入失败，请手动添加："
    MSG_HAS_HOOKS="settings.json 已有 hooks 配置"
    MSG_MERGE_MANUAL="请手动合并："
    MSG_ADD_TO_FILE="将以下内容添加到 ~/.claude/settings.json："
else
    MSG_USING_JQ="Using jq for JSON merging"
    MSG_BACKED_UP="Backed up existing settings to"
    MSG_MERGED="Merged hooks into existing settings"
    MSG_CREATED="Created new settings file"
    MSG_SUCCESS="Claude Code hooks configured successfully!"
    MSG_NO_JQ="jq not found, using fallback method"
    MSG_INSERTED="Inserted hooks into settings"
    MSG_INSERT_FAILED="Auto-insert failed. Please add manually:"
    MSG_HAS_HOOKS="settings.json already has hooks config"
    MSG_MERGE_MANUAL="Please merge manually:"
    MSG_ADD_TO_FILE="Add the following to your ~/.claude/settings.json:"
fi

print_info() { echo -e "${GREEN}==>${NC} $1"; }
print_warn() { echo -e "${YELLOW}Warning:${NC} $1"; }

# Generate hooks JSON
generate_hooks_json() {
    cat <<EOF
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          { "type": "command", "command": "${HOOKS_DIR}/on-task-start.sh" }
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "permission_prompt|elicitation_dialog",
        "hooks": [
          { "type": "command", "command": "${HOOKS_DIR}/on-need-input.sh" }
        ]
      }
    ],
    "PreToolUse": [
      {
        "hooks": [
          { "type": "command", "command": "${HOOKS_DIR}/on-tool-use.sh" }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": "${HOOKS_DIR}/on-task-end.sh" }
        ]
      }
    ]
  }
}
EOF
}

# Print hooks config for manual copy
print_hooks_config() {
    echo ""
    echo "$MSG_ADD_TO_FILE"
    echo ""
    generate_hooks_json
    echo ""
}

# Ensure ~/.claude directory exists
mkdir -p "$HOME/.claude"

# Check if jq is available
if command -v jq &>/dev/null; then
    print_info "$MSG_USING_JQ"

    HOOKS_JSON=$(generate_hooks_json)

    if [[ -f "$SETTINGS_FILE" ]]; then
        cp "$SETTINGS_FILE" "$BACKUP_FILE"
        print_info "$MSG_BACKED_UP $BACKUP_FILE"

        MERGED=$(jq -s '.[0] * .[1]' "$SETTINGS_FILE" <(echo "$HOOKS_JSON"))
        echo "$MERGED" > "$SETTINGS_FILE"
        print_info "$MSG_MERGED"
    else
        echo "$HOOKS_JSON" > "$SETTINGS_FILE"
        print_info "$MSG_CREATED"
    fi

    echo ""
    print_info "$MSG_SUCCESS"

else
    print_warn "$MSG_NO_JQ"

    if [[ ! -f "$SETTINGS_FILE" ]]; then
        generate_hooks_json > "$SETTINGS_FILE"
        print_info "$MSG_CREATED"
        print_info "$MSG_SUCCESS"

    elif ! grep -q '"hooks"' "$SETTINGS_FILE"; then
        cp "$SETTINGS_FILE" "$BACKUP_FILE"
        print_info "$MSG_BACKED_UP $BACKUP_FILE"

        HOOKS_CONTENT=$(cat <<'HOOKS'
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          { "type": "command", "command": "HOOKS_DIR/on-task-start.sh" }
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "permission_prompt|elicitation_dialog",
        "hooks": [
          { "type": "command", "command": "HOOKS_DIR/on-need-input.sh" }
        ]
      }
    ],
    "PreToolUse": [
      {
        "hooks": [
          { "type": "command", "command": "HOOKS_DIR/on-tool-use.sh" }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": "HOOKS_DIR/on-task-end.sh" }
        ]
      }
    ]
  },
HOOKS
)
        HOOKS_CONTENT="${HOOKS_CONTENT//HOOKS_DIR/$HOOKS_DIR}"

        if sed -i.tmp "s|^{|{\n${HOOKS_CONTENT}|" "$SETTINGS_FILE" 2>/dev/null; then
            rm -f "${SETTINGS_FILE}.tmp"
            print_info "$MSG_INSERTED"
            print_info "$MSG_SUCCESS"
        else
            mv "$BACKUP_FILE" "$SETTINGS_FILE"
            print_warn "$MSG_INSERT_FAILED"
            print_hooks_config
        fi

    else
        print_warn "$MSG_HAS_HOOKS"
        print_warn "$MSG_MERGE_MANUAL"
        print_hooks_config
    fi
fi
