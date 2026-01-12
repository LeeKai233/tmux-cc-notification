<p align="center">
  <img src="assets/logo/fish.svg" alt="tmux-cc-notification" width="120" />
</p>

<h1 align="center">tmux-cc-notification</h1>

<p align="center">
  <strong>🔔 Windows Toast notifications for Claude Code in WSL2/tmux</strong>
</p>

<p align="center">
  <a href="#-quick-start">Quick Start</a> •
  <a href="#-features">Features</a> •
  <a href="#-installation">Installation</a> •
  <a href="#%EF%B8%8F-configuration">Configuration</a> •
  <a href="#-troubleshooting">Troubleshooting</a>
</p>

<p align="center">
  <a href="README.zh-CN.md">中文文档</a>
</p>

---

## 💡 What is this?

When running Claude Code in a tmux pane, you might miss important events while working in other windows. This tool sends **Windows Toast notifications** so you always know:

- ⏱️ Your task is still running (periodic updates)
- ⚠️ Claude needs your input or permission
- ✅ Your task is complete

**Click any notification to instantly jump back to your Claude Code pane.**

---

## 🚀 Quick Start

> **Prerequisites**: Windows 10/11 with WSL2, Windows Terminal, tmux

### Step 1: Install PowerShell 7 (Windows)

Open PowerShell as Administrator and run:

```powershell
winget install Microsoft.PowerShell
```

Or download from [aka.ms/powershell](https://aka.ms/powershell)

### Step 2: Install BurntToast Module (Windows)

Open PowerShell 7 (`pwsh`) and run:

```powershell
Install-Module -Name BurntToast -Scope CurrentUser
```

### Step 3: Install in WSL2

```bash
# Clone the repository
git clone https://github.com/nicholasgcoles/tmux-cc-notification.git ~/.claude/hooks/tmux-cc-notification

# Run the installer
cd ~/.claude/hooks/tmux-cc-notification
./scripts/install.sh

# Test it works
./scripts/test-notification.sh all
```

**Done!** 🎉 The installer automatically configures Claude Code hooks.

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| **Periodic Notifications** | Progress updates every 5 minutes (configurable) |
| **Input Required Alerts** | Instant notification when Claude needs permission |
| **Task Completion** | Notification with hero image when done |
| **Click-to-Focus** | Click notification → switch to correct tmux pane |
| **Smart Suppression** | No spam when you're already viewing the pane |

---

## 📦 Installation

### Prerequisites Checklist

| Requirement | Where | How to Check |
|-------------|-------|--------------|
| WSL2 | Windows | `wsl --version` |
| Windows Terminal | Windows | Should be default terminal |
| PowerShell 7 | Windows | `pwsh --version` |
| BurntToast | Windows | `Get-Module -ListAvailable BurntToast` |
| tmux | WSL2 | `tmux -V` |
| jq (optional) | WSL2 | `jq --version` |

### Install Missing Dependencies

<details>
<summary><strong>📥 Install jq and tmux in WSL2</strong></summary>

```bash
sudo apt update && sudo apt install -y jq tmux
```

</details>

<details>
<summary><strong>📥 Install PowerShell 7 on Windows</strong></summary>

Option 1 - Using winget (recommended):

```powershell
winget install Microsoft.PowerShell
```

Option 2 - Manual download:
Visit [aka.ms/powershell](https://aka.ms/powershell)

</details>

<details>
<summary><strong>📥 Install BurntToast Module</strong></summary>

Open PowerShell 7 (`pwsh`) and run:

```powershell
Install-Module -Name BurntToast -Scope CurrentUser -Force
```

</details>

### Run the Installer

```bash
cd ~/.claude/hooks/tmux-cc-notification
./scripts/install.sh
```

The installer will:

1. ✅ Check all dependencies
2. ✅ Register `ccnotify://` URI protocol (for click-to-focus)
3. ✅ Configure Claude Code hooks in `~/.claude/settings.json`
4. ✅ Send a test notification

---

## ⚙️ Configuration

Copy the example config and customize:

```bash
cp config.example.toml .tmux_cc_notify_conf.toml
```

### Configuration Options

```toml
[running]
enabled = true
interval_minutes = 5        # How often to notify during long tasks
sound_path = "C:\\Windows\\Media\\chimes.wav"
sound_repeat = 1

[need_input]
enabled = true
sound_path = "C:\\Windows\\Media\\notify.wav"
sound_repeat = 2            # Play sound twice for urgency

[done]
enabled = true
sound_path = "C:\\Windows\\Media\\tada.wav"
sound_repeat = 1

[suppress]
enabled = true              # Skip notifications when viewing the pane

[text]
title = "{session} Claude Code"
running_body = "[Running: {mm} min] {prompt}"
done_body = "[Total: {mm} min] {prompt}"
need_input_body = "Permission/input required"
prompt_max_chars = 60
```

### Template Variables

| Variable | Description |
|----------|-------------|
| `{session}` | tmux session name |
| `{mm}` | Elapsed minutes |
| `{prompt}` | User's input (truncated) |

---

## 🧪 Testing

```bash
# Test all notification types
./scripts/test-notification.sh all

# Test specific types
./scripts/test-notification.sh running   # Progress notification
./scripts/test-notification.sh input     # Input required notification
./scripts/test-notification.sh done      # Completion notification
./scripts/test-notification.sh click     # Click-to-focus functionality

# Clean up test notifications
./scripts/test-notification.sh cleanup
```

---

## 🔧 Troubleshooting

### Check Dependencies First

```bash
./scripts/check-deps.sh
```

### Enable Debug Logging

```bash
export CC_NOTIFY_DEBUG=1
# Logs written to: $XDG_STATE_HOME/cc-notify/ or /tmp/cc-notify.log
```

<details>
<summary><strong>❌ Notifications not appearing</strong></summary>

1. Verify BurntToast is installed:

   ```powershell
   Get-Module -ListAvailable BurntToast
   ```

2. Check Windows notification settings:
   - Settings → System → Notifications
   - Ensure Windows Terminal notifications are enabled

3. Run dependency check:

   ```bash
   ./scripts/check-deps.sh
   ```

</details>

<details>
<summary><strong>❌ Click-to-focus not working</strong></summary>

1. Re-register the URI protocol:

   ```bash
   pwsh.exe -File ps/install-protocol.ps1
   ```

2. Check registry entry exists:

   ```powershell
   Get-Item "HKCU:\Software\Classes\ccnotify"
   ```

</details>

<details>
<summary><strong>❌ Sound not playing</strong></summary>

1. Verify sound file exists at the configured path
2. Check Windows volume settings
3. Try a different sound file path

</details>

<details>
<summary><strong>❌ PowerShell execution policy errors</strong></summary>

WSL paths (`\\wsl.localhost\...`) are treated as remote by Windows. The scripts use `-ExecutionPolicy Bypass` for the current process only.

If you see "script cannot be loaded" errors:

1. Ensure `pwsh_execution_policy = "Bypass"` in your config
2. Or copy the config template: `cp config.example.toml .tmux_cc_notify_conf.toml`

</details>

---

## 🏗️ Architecture

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

For detailed architecture documentation, see [docs/C4-Documentation/](docs/C4-Documentation/).

---

## 📄 License

MIT License - see [LICENSE](LICENSE)

## 🤝 Contributing

Contributions welcome! Please feel free to submit a Pull Request.
