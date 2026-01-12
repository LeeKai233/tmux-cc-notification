#!/bin/bash
# install.sh - One-click installer for tmux-cc-notification
# 一键安装脚本

set -e

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$INSTALL_DIR")"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --lang)
            LANG_CODE="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Detect language (zh_CN, zh_TW, zh_HK, ja, ko → Chinese; otherwise → English)
# Also check Windows locale via PowerShell in WSL environment
detect_lang() {
    local lang="${LC_ALL:-${LC_MESSAGES:-${LANG:-en}}}"
    case "$lang" in
        zh_*|ja_*|ko_*) echo "zh"; return ;;
    esac
    # Try Windows locale detection in WSL (check system locale, not user format)
    if command -v powershell.exe &>/dev/null; then
        local win_locale
        win_locale=$(powershell.exe -NoProfile -Command '(Get-WinSystemLocale).Name' 2>/dev/null | tr -d '\r')
        case "$win_locale" in
            zh-*|ja-*|ko-*) echo "zh"; return ;;
        esac
    fi
    echo "en"
}

# Use provided LANG_CODE or detect
if [[ -z "$LANG_CODE" ]]; then
    LANG_CODE=$(detect_lang)
fi
export LANG_CODE

# Messages
if [[ "$LANG_CODE" == "zh" ]]; then
    MSG_TITLE="tmux-cc-notification 安装程序"
    MSG_CHECKING_DEPS="检查依赖..."
    MSG_DEPS_MISSING="缺少部分依赖，请先安装。"
    MSG_INSTALL_DEPS="安装缺失的依赖："
    MSG_DEPS_OK="所有依赖已满足！"
    MSG_SETUP_CONFIG="配置设置..."
    MSG_CONFIG_CREATED="从模板创建配置文件"
    MSG_CONFIG_EXISTS="配置文件已存在"
    MSG_CONFIG_DEFAULT="使用默认配置"
    MSG_REG_PROTOCOL="注册 ccnotify:// 协议..."
    MSG_REG_FAILED="协议注册可能失败，可手动运行："
    MSG_SETUP_HOOKS="配置 Claude Code 钩子..."
    MSG_TEST_NOTIFY="测试通知..."
    MSG_TEST_FAILED="测试通知可能失败，可手动运行："
    MSG_COMPLETE="安装完成！"
    MSG_NEXT_STEPS="后续步骤："
    MSG_CUSTOMIZE="自定义配置文件"
    MSG_TEST="测试通知"
else
    MSG_TITLE="tmux-cc-notification Installer"
    MSG_CHECKING_DEPS="Checking dependencies..."
    MSG_DEPS_MISSING="Some dependencies are missing. Please install them first."
    MSG_INSTALL_DEPS="Install missing dependencies:"
    MSG_DEPS_OK="All dependencies satisfied!"
    MSG_SETUP_CONFIG="Setting up configuration..."
    MSG_CONFIG_CREATED="Created config file from template"
    MSG_CONFIG_EXISTS="Config file already exists"
    MSG_CONFIG_DEFAULT="Using default configuration"
    MSG_REG_PROTOCOL="Registering ccnotify:// protocol..."
    MSG_REG_FAILED="Protocol registration may have failed. You can run it manually:"
    MSG_SETUP_HOOKS="Configuring Claude Code hooks..."
    MSG_TEST_NOTIFY="Testing notification..."
    MSG_TEST_FAILED="Test notification may have failed. Run manually:"
    MSG_COMPLETE="Installation complete!"
    MSG_NEXT_STEPS="Next steps:"
    MSG_CUSTOMIZE="Customize config file"
    MSG_TEST="Test notifications"
fi

print_step() { echo -e "${GREEN}==>${NC} $1"; }
print_warn() { echo -e "${YELLOW}Warning:${NC} $1"; }
print_error() { echo -e "${RED}Error:${NC} $1"; }

# Source dependencies
source "${BASE_DIR}/lib/deps.sh"
source "${BASE_DIR}/lib/pwsh.sh"

echo "============================================"
echo "  $MSG_TITLE"
echo "============================================"
echo ""

# Step 1: Check dependencies
print_step "$MSG_CHECKING_DEPS"
print_dependency_status

if ! all_dependencies_met; then
    echo ""
    print_error "$MSG_DEPS_MISSING"
    echo ""
    echo "$MSG_INSTALL_DEPS"
    echo "  - jq: sudo apt install jq"
    echo "  - tmux: sudo apt install tmux"
    echo "  - PowerShell 7: https://aka.ms/powershell"
    echo "  - BurntToast: Install-Module -Name BurntToast -Scope CurrentUser"
    echo ""
    exit 1
fi

echo ""
print_step "$MSG_DEPS_OK"
echo ""

# Step 2: Copy config template
print_step "$MSG_SETUP_CONFIG"
CONFIG_FILE="${BASE_DIR}/.tmux_cc_notify_conf.toml"
EXAMPLE_FILE="${BASE_DIR}/config.example.toml"

if [[ ! -f "$CONFIG_FILE" ]] && [[ -f "$EXAMPLE_FILE" ]]; then
    cp "$EXAMPLE_FILE" "$CONFIG_FILE"
    echo "  $MSG_CONFIG_CREATED"
elif [[ -f "$CONFIG_FILE" ]]; then
    echo "  $MSG_CONFIG_EXISTS"
else
    echo "  $MSG_CONFIG_DEFAULT"
fi

# Step 3: Register URI protocol
print_step "$MSG_REG_PROTOCOL"
PWSH=$(find_pwsh)
PS_INSTALL="${BASE_DIR}/ps/install-protocol.ps1"
WIN_PS_INSTALL=$(wslpath -w "$PS_INSTALL" 2>/dev/null || echo "$PS_INSTALL")

"$PWSH" -NoProfile -ExecutionPolicy Bypass -File "$WIN_PS_INSTALL" -Lang "$LANG_CODE" 2>/dev/null || {
    print_warn "$MSG_REG_FAILED"
    echo "  pwsh -File \"$WIN_PS_INSTALL\""
}

# Step 4: Setup Claude Code hooks
print_step "$MSG_SETUP_HOOKS"
"${INSTALL_DIR}/setup-hooks.sh"

# Step 5: Test notification
print_step "$MSG_TEST_NOTIFY"
"${INSTALL_DIR}/test-notification.sh" done 2>/dev/null || {
    print_warn "$MSG_TEST_FAILED"
    echo "  ${INSTALL_DIR}/test-notification.sh all"
}

echo ""
echo "============================================"
echo "  $MSG_COMPLETE"
echo "============================================"
echo ""
echo "$MSG_NEXT_STEPS"
echo "1. $MSG_CUSTOMIZE: ${CONFIG_FILE}"
echo "2. $MSG_TEST: ${INSTALL_DIR}/test-notification.sh all"
echo ""
