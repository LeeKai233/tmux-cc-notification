#!/bin/bash
# check-deps.sh - Standalone dependency checker / 独立依赖检查脚本
# Run this to verify all dependencies are installed

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

source "${BASE_DIR}/lib/deps.sh"

echo "============================================"
echo "  tmux-cc-notification Dependency Check"
echo "  tmux-cc-notification 依赖检查"
echo "============================================"
echo ""

print_dependency_status

echo ""
if all_dependencies_met; then
    echo "✓ All dependencies are satisfied!"
    echo "✓ 所有依赖已满足！"
    exit 0
else
    echo "✗ Some dependencies are missing."
    echo "✗ 缺少部分依赖。"
    echo ""
    echo "Please install missing dependencies before using this tool."
    echo "请在使用此工具前安装缺失的依赖。"
    exit 1
fi
