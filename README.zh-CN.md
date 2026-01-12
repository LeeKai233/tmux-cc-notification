<p align="center">
  <img src="assets/logo/fish.svg" alt="tmux-cc-notification" width="120" />
</p>

<h1 align="center">tmux-cc-notification</h1>

<p align="center">
  <strong>🔔 在 WSL2/tmux 中为 Claude Code 提供 Windows Toast 通知</strong>
</p>

<p align="center">
  <a href="#quick-start">快速开始</a> •
  <a href="#features">功能特性</a> •
  <a href="#installation">安装</a> •
  <a href="#configuration">配置</a> •
  <a href="#troubleshooting">故障排除</a>
</p>

<p align="center">
  <a href="README.md">English</a>
</p>

---

## 💡 这是什么？

当你在 tmux pane 里运行 Claude Code、同时又在其他窗口工作时，很容易错过关键事件。这个工具会发送 **Windows Toast 通知**，让你始终知道：

- ⏱️ 任务仍在运行（周期性更新）
- ⚠️ Claude 需要你的输入或授权
- ✅ 任务已完成

**点击任意通知即可立刻跳回 Claude Code 所在的 tmux pane。**

---

<a id="quick-start"></a>

## 🚀 快速开始

> **前置条件**：Windows 10/11（含 WSL2）、Windows Terminal、tmux

### 第 1 步：安装 PowerShell 7（Windows）

以管理员身份打开 PowerShell 并运行：

```powershell
winget install Microsoft.PowerShell
```

或从 [aka.ms/powershell](https://aka.ms/powershell) 下载。

### 第 2 步：安装 BurntToast 模块（Windows）

打开 PowerShell 7（`pwsh`）并运行：

```powershell
Install-Module -Name BurntToast -Scope CurrentUser
```

### 第 3 步：在 WSL2 中安装

```bash
# 克隆仓库
git clone https://github.com/nicholasgcoles/tmux-cc-notification.git ~/.claude/hooks/tmux-cc-notification

# 运行安装脚本
cd ~/.claude/hooks/tmux-cc-notification
./scripts/install.sh

# 测试是否可用
./scripts/test-notification.sh all
```

安装脚本会自动配置 Claude Code hooks。

---

<a id="features"></a>

## ✨ 功能特性

| 功能 | 说明 |
|---------|-------------|
| **周期性通知** | 每 5 分钟发送一次进度更新（可配置） |
| **需要输入提醒** | Claude 需要授权/输入时立即通知 |
| **任务完成** | 完成时带 Hero 图片的通知 |
| **点击聚焦** | 点击通知 → 切换到正确的 tmux pane |
| **智能抑制** | 当你正在查看对应 pane 时不打扰 |

---

<a id="installation"></a>

## 📦 安装

### 前置条件清单

| 需求 | 位置 | 如何检查 |
|-------------|-------|--------------|
| WSL2 | Windows | `wsl --version` |
| Windows Terminal | Windows | 应为默认终端 |
| PowerShell 7 | Windows | `pwsh --version` |
| BurntToast | Windows | `Get-Module -ListAvailable BurntToast` |
| tmux | WSL2 | `tmux -V` |
| jq（可选） | WSL2 | `jq --version` |

### 安装缺失依赖

<details>
<summary><strong>📥 在 WSL2 中安装 jq 与 tmux</strong></summary>

```bash
sudo apt update && sudo apt install -y jq tmux
```

</details>

<details>
<summary><strong>📥 在 Windows 上安装 PowerShell 7</strong></summary>

方式 1：使用 winget（推荐）：

```powershell
winget install Microsoft.PowerShell
```

方式 2：手动下载：
访问 [aka.ms/powershell](https://aka.ms/powershell)

</details>

<details>
<summary><strong>📥 安装 BurntToast 模块</strong></summary>

打开 PowerShell 7（`pwsh`）并运行：

```powershell
Install-Module -Name BurntToast -Scope CurrentUser -Force
```

</details>

### 运行安装脚本

```bash
cd ~/.claude/hooks/tmux-cc-notification
./scripts/install.sh
```

安装脚本会：

1. ✅ 检查所有依赖
2. ✅ 注册 `ccnotify://` URI 协议（用于点击聚焦）
3. ✅ 在 `~/.claude/settings.json` 中配置 Claude Code hooks
4. ✅ 发送一条测试通知

---

<a id="configuration"></a>

## ⚙️ 配置

复制示例配置并按需修改：

```bash
cp config.example.toml .tmux_cc_notify_conf.toml
```

### 配置项

```toml
[running]
enabled = true
interval_minutes = 5        # 长任务期间的通知频率
sound_path = "C:\\Windows\\Media\\chimes.wav"
sound_repeat = 1

[need_input]
enabled = true
sound_path = "C:\\Windows\\Media\\notify.wav"
sound_repeat = 2            # 更紧急时播放两次

[done]
enabled = true
sound_path = "C:\\Windows\\Media\\tada.wav"
sound_repeat = 1

[suppress]
enabled = true              # 当你正在查看 pane 时跳过通知

[text]
title = "{session} Claude Code"
running_body = "[Running: {mm} min] {prompt}"
done_body = "[Total: {mm} min] {prompt}"
need_input_body = "Permission/input required"
prompt_max_chars = 60
```

### 模板变量

| 变量 | 说明 |
|----------|-------------|
| `{session}` | tmux 会话名称 |
| `{mm}` | 已耗时分钟数 |
| `{prompt}` | 用户输入（会截断） |

---

## 🧪 测试

```bash
# 测试所有通知类型
./scripts/test-notification.sh all

# 测试特定类型
./scripts/test-notification.sh running   # 进度通知
./scripts/test-notification.sh input     # 需要输入通知
./scripts/test-notification.sh done      # 完成通知
./scripts/test-notification.sh click     # 点击聚焦功能

# 清理测试通知
./scripts/test-notification.sh cleanup
```

---

<a id="troubleshooting"></a>

## 🔧 故障排除

### 先检查依赖

```bash
./scripts/check-deps.sh
```

### 启用调试日志

```bash
export CC_NOTIFY_DEBUG=1
# 日志位置：$XDG_STATE_HOME/cc-notify/ 或 /tmp/cc-notify.log
```

<details>
<summary><strong>❌ 通知不显示</strong></summary>

1. 确认 BurntToast 已安装：

   ```powershell
   Get-Module -ListAvailable BurntToast
   ```

2. 检查 Windows 通知设置：
   - 设置 → 系统 → 通知
   - 确认已允许 Windows Terminal 的通知

3. 运行依赖检查：

   ```bash
   ./scripts/check-deps.sh
   ```

</details>

<details>
<summary><strong>❌ 点击聚焦不工作</strong></summary>

1. 重新注册 URI 协议：

   ```bash
   pwsh.exe -File ps/install-protocol.ps1
   ```

2. 检查注册表项是否存在：

   ```powershell
   Get-Item "HKCU:\Software\Classes\ccnotify"
   ```

</details>

<details>
<summary><strong>❌ 声音不播放</strong></summary>

1. 确认配置的声音文件路径存在
2. 检查 Windows 音量设置
3. 尝试更换为其他声音文件路径

</details>

<details>
<summary><strong>❌ PowerShell 执行策略报错</strong></summary>

WSL 路径（`\\wsl.localhost\...`）会被 Windows 视为“远程位置”。脚本使用 `-ExecutionPolicy Bypass`，仅影响当前 PowerShell 进程，不会修改系统级执行策略。

如果出现 “script cannot be loaded” 等报错：

1. 确认你的配置中包含 `pwsh_execution_policy = "Bypass"`
2. 或复制配置模板：`cp config.example.toml .tmux_cc_notify_conf.toml`

</details>

---

## 🏗️ 架构

```txt
WSL2 (Bash)                      Windows (PowerShell)
┌──────────────────┐             ┌──────────────────┐
│  Claude Code     │             │  BurntToast      │
│  Hook Events     │────────────▶│  Toast API       │
│                  │   pwsh.exe  │                  │
│  State Manager   │             │  URI Protocol    │
│  (cache files)   │◀────────────│  Handler         │
└──────────────────┘  ccnotify:// └──────────────────┘
```

更详细的架构文档请参阅 [docs/C4-Documentation/](docs/C4-Documentation/)。

---

## 📄 许可证

MIT License - 见 [LICENSE](LICENSE)

## 🤝 贡献

欢迎贡献！请随时提交 Pull Request。
