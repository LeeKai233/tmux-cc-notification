# tmux-cc-notification

Windows Toast notifications for Claude Code running in WSL2/tmux.

[中文文档](README.zh-CN.md)

## Features

- **Periodic notifications**: Get notified every 5 minutes when a task is running (configurable)
- **Input required notifications**: Instant notification when Claude needs your permission or input
- **Task completion notifications**: Know when your task is done with a hero image
- **Click-to-focus**: Click notification to switch to the correct tmux pane
- **Smart suppression**: No notifications when you're already viewing the task pane

## Requirements

- Windows 10/11 with WSL2
- Windows Terminal
- PowerShell 7 ([Download](https://aka.ms/powershell))
- [BurntToast](https://github.com/Windos/BurntToast) PowerShell module
- tmux
- jq (optional, for better JSON handling)

## Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/YOUR_USERNAME/tmux-cc-notification.git
cd tmux-cc-notification

# 2. Run the installer (auto-configures Claude Code hooks)
./scripts/install.sh

# 3. Test notifications
./scripts/test-notification.sh all
```

That's it! The installer automatically configures `~/.claude/settings.json`.

## Installation

### 1. Install Dependencies

```bash
# Install jq and tmux (if not already installed)
sudo apt install jq tmux

# Install BurntToast PowerShell module (run in PowerShell)
Install-Module -Name BurntToast -Scope CurrentUser
```

### 2. Run Installer

```bash
./scripts/install.sh
```

The installer will:

- Check all dependencies
- Register the `ccnotify://` URI protocol for click-to-focus
- Auto-configure Claude Code hooks in `~/.claude/settings.json`
- Send a test notification

### Manual Hook Configuration (Optional)

If you prefer to configure hooks manually, run:

```bash
./scripts/setup-hooks.sh
```

Or add the following to your `~/.claude/settings.json`:

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

## Configuration

Copy `config.example.toml` to `.tmux_cc_notify_conf.toml` and customize:

```toml
[assets]
# Optional: Custom app logo and hero image
# app_logo = "C:\\path\\to\\logo.png"
# hero_image_task_end = "C:\\path\\to\\hero.png"

[text]
title = "{session} Claude Code"
running_body = "[Running: {mm} min] {prompt}"
done_body = "[Total: {mm} min] {prompt}"
need_input_body = "Permission/input required"
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

### Template Variables

- `{session}` - tmux session name
- `{mm}` - elapsed minutes
- `{prompt}` - user's input (truncated)

## Testing

```bash
# Test all notification types
./scripts/test-notification.sh all

# Test specific notification
./scripts/test-notification.sh running
./scripts/test-notification.sh input
./scripts/test-notification.sh done

# Test click-to-focus
./scripts/test-notification.sh click

# Cleanup test notifications
./scripts/test-notification.sh cleanup
```

## Debugging

Enable debug logging:

```bash
export CC_NOTIFY_DEBUG=1
# Logs will be written to /tmp/cc-notify.log
```

Check dependencies:

```bash
./scripts/check-deps.sh
```

## How It Works

1. **Task Start**: When you submit a prompt to Claude Code, the hook captures the session info and starts a background monitor
2. **Periodic Monitor**: Every 30 seconds, checks if it's time to send a progress notification (default: every 5 minutes)
3. **Input Required**: When Claude needs permission or user input, sends an immediate notification
4. **Task End**: Sends completion notification and cleans up

### Architecture

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

## Troubleshooting

### Notifications not appearing

1. Check if BurntToast is installed: `Get-Module -ListAvailable BurntToast`
2. Check Windows notification settings for Windows Terminal
3. Run `./scripts/check-deps.sh` to verify all dependencies

### Click-to-focus not working

1. Re-run protocol registration: `pwsh -File ps/install-protocol.ps1`
2. Check if the VBS file path is correct in registry

### Sound not playing

1. Verify the sound file path exists
2. Check Windows volume settings

## License

MIT License - see [LICENSE](LICENSE)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
