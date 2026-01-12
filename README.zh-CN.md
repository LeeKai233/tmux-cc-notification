# tmux-cc-notification

在 WSL2/tmux 中运行 Claude Code 时获取 Windows Toast 通知。

[English](README.md)

## 功能特性

- **周期性通知**：任务运行时每 5 分钟通知一次（可配置）
- **输入请求通知**：当 Claude 需要权限或输入时立即通知
- **任务完成通知**：任务完成时带有 Hero 图片的通知
- **点击跳转**：点击通知可切换到对应的 tmux pane
- **智能抑制**：当你正在查看任务 pane 时不发送通知

## 系统要求

- Windows 10/11 + WSL2
- Windows Terminal
- PowerShell 7 ([下载](https://aka.ms/powershell))
- [BurntToast](https://github.com/Windos/BurntToast) PowerShell 模块
- tmux
- jq（可选，用于更好的 JSON 处理）

## 快速开始

```bash
# 1. 克隆仓库
git clone https://github.com/YOUR_USERNAME/tmux-cc-notification.git
cd tmux-cc-notification

# 2. 运行安装脚本（自动配置 Claude Code 钩子）
./scripts/install.sh

# 3. 测试通知
./scripts/test-notification.sh all
```

就这么简单！安装脚本会自动配置 `~/.claude/settings.json`。

## 安装步骤

### 1. 安装依赖

```bash
# 安装 jq 和 tmux（如果尚未安装）
sudo apt install jq tmux

# 安装 BurntToast PowerShell 模块（在 PowerShell 中运行）
Install-Module -Name BurntToast -Scope CurrentUser
```

### 2. 运行安装脚本

```bash
./scripts/install.sh
```

安装脚本会：

- 检查所有依赖
- 注册 `ccnotify://` URI 协议用于点击跳转
- 自动配置 Claude Code 钩子到 `~/.claude/settings.json`
- 发送测试通知

### 手动配置钩子（可选）

如果你想手动配置钩子，运行：

```bash
./scripts/setup-hooks.sh
```

或将以下内容添加到 `~/.claude/settings.json`：

```json
{
  "hooks": {
    "UserPromptSubmit": [
      { "matcher": "", "hooks": ["/path/to/tmux-cc-notification/hooks/on-task-start.sh"] }
    ],
    "Notification": [
      { "matcher": "", "hooks": ["/path/to/tmux-cc-notification/hooks/on-need-input.sh"] }
    ],
    "PreToolUse": [
      { "matcher": "", "hooks": ["/path/to/tmux-cc-notification/hooks/on-tool-use.sh"] }
    ],
    "Stop": [
      { "matcher": "", "hooks": ["/path/to/tmux-cc-notification/hooks/on-task-end.sh"] }
    ]
  }
}
```

## 配置说明

复制 `config.example.toml` 到 `.tmux_cc_notify_conf.toml` 并自定义：

```toml
[assets]
# 可选：自定义应用图标和 Hero 图片
# app_logo = "C:\\path\\to\\logo.png"
# hero_image_task_end = "C:\\path\\to\\hero.png"

[text]
title = "{session} Claude Code"
running_body = "【已进行：{mm} 分钟】{prompt}"
done_body = "【总耗时：{mm} 分钟】{prompt}"
need_input_body = "权限/需求待确认"
prompt_max_chars = 60

[running]
enabled = true
interval_minutes = 5
sound_path = "C:\\Windows\\Media\\chimes.wav"
sound_repeat = 1

[need_input]
enabled = true
sound_path = "C:\\Windows\\Media\\notify.wav"
sound_repeat = 2

[done]
enabled = true
sound_path = "C:\\Windows\\Media\\tada.wav"
sound_repeat = 1

[suppress]
enabled = true
```

### 模板变量

- `{session}` - tmux session 名称
- `{mm}` - 已运行分钟数
- `{prompt}` - 用户输入（截断后）

## 测试

```bash
# 测试所有通知类型
./scripts/test-notification.sh all

# 测试特定通知
./scripts/test-notification.sh running
./scripts/test-notification.sh input
./scripts/test-notification.sh done

# 测试点击跳转
./scripts/test-notification.sh click

# 清理测试通知
./scripts/test-notification.sh cleanup
```

## 调试

启用调试日志：

```bash
export CC_NOTIFY_DEBUG=1
# 日志将写入 /tmp/cc-notify.log
```

检查依赖：

```bash
./scripts/check-deps.sh
```

## 工作原理

1. **任务开始**：当你向 Claude Code 提交 prompt 时，钩子捕获会话信息并启动后台监控
2. **周期监控**：每 30 秒检查是否需要发送进度通知（默认每 5 分钟）
3. **输入请求**：当 Claude 需要权限或用户输入时，立即发送通知
4. **任务结束**：发送完成通知并清理状态

### 架构

```txt
WSL2 (Bash)                    Windows (PowerShell)
┌─────────────────┐            ┌─────────────────┐
│ Claude Code     │            │ BurntToast      │
│ Hooks           │───────────▶│ Toast API       │
│                 │            │                 │
│ State Manager   │            │ URI Protocol    │
│ (/tmp/cc-notify)│◀───────────│ Handler         │
└─────────────────┘            └─────────────────┘
```

## 故障排除

### 通知不显示

1. 检查 BurntToast 是否安装：`Get-Module -ListAvailable BurntToast`
2. 检查 Windows Terminal 的 Windows 通知设置
3. 运行 `./scripts/check-deps.sh` 验证所有依赖

### 点击跳转不工作

1. 重新运行协议注册：`pwsh -File ps/install-protocol-local.ps1`
2. 检查注册表中 VBS 文件路径是否正确

### 声音不播放

1. 验证声音文件路径是否存在
2. 检查 Windows 音量设置

### PowerShell 执行策略

本工具需要 `Bypass` 执行策略，因为 Windows 将 WSL 文件路径（`\\wsl.localhost\...`）视为远程位置。脚本使用 `-ExecutionPolicy Bypass`，这只影响当前 PowerShell 进程，不会更改系统级策略。

如果看到"脚本无法加载"或"未经数字签名"等错误：

1. 确保配置文件中设置了 `pwsh_execution_policy = "Bypass"`
2. 或复制配置模板：`cp config.example.toml .tmux_cc_notify_conf.toml`

如需更严格的安全性，可以使用代码签名证书为 PowerShell 脚本签名，然后使用 `RemoteSigned` 策略。

## 许可证

MIT License - 见 [LICENSE](LICENSE)

## 贡献

欢迎贡献！请随时提交 Pull Request。
