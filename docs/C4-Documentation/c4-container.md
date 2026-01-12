# C4 Container-Level Documentation

## Containers Overview

The tmux-cc-notification system consists of two main containers that communicate across the WSL2/Windows boundary:

| Container | Type | Technology | Description |
|-----------|------|------------|-------------|
| WSL2 Bash Runtime | Application | Bash, tmux | Processes Claude Code events and manages state |
| Windows PowerShell Runtime | Application | PowerShell 7, BurntToast | Displays notifications and handles user interactions |

## Container: WSL2 Bash Runtime

### Overview

- **Name**: WSL2 Bash Runtime
- **Type**: Application
- **Technology**: Bash Shell, tmux
- **Deployment**: WSL2 Linux environment

### Purpose

Runs within the WSL2 environment alongside Claude Code. Receives hook events, manages task state, and coordinates notification delivery.

### Components

| Component | Description |
|-----------|-------------|
| [Hook Event Handler](c4-component-hook-handler.md) | Processes Claude Code lifecycle events |
| [Configuration](c4-component-configuration.md) | Manages application settings |
| [Installation & Testing](c4-component-installation.md) | Setup and verification scripts |

### Interfaces

#### Input: Claude Code Hooks

| Event | Protocol | Description |
|-------|----------|-------------|
| UserPromptSubmit | stdin JSON | Task started |
| PreToolUse | stdin JSON | Tool being used |
| Notification | stdin JSON | Input required |
| Stop | stdin JSON | Task completed |

#### Output: PowerShell Invocation

| Operation | Protocol | Description |
|-----------|----------|-------------|
| send-toast.ps1 | Process spawn | Send notification |
| install-protocol.ps1 | Process spawn | Register URI protocol |

### Infrastructure

- **State Storage**: `$XDG_CACHE_HOME/cc-notify/{session_id}/`
- **Log Storage**: `$XDG_STATE_HOME/cc-notify/`
- **Config File**: `.tmux_cc_notify_conf.toml`

---

## Container: Windows PowerShell Runtime

### Overview

- **Name**: Windows PowerShell Runtime
- **Type**: Application
- **Technology**: PowerShell 7, BurntToast Module
- **Deployment**: Windows host (via pwsh.exe)

### Purpose

Runs on the Windows host to interface with the Windows Toast API. Displays notifications and handles click-to-focus actions.

### Components

| Component | Description |
|-----------|-------------|
| [Windows Notification](c4-component-windows-notification.md) | Toast notifications and click handling |

### Interfaces

#### Input: Script Invocation

| Script | Parameters | Description |
|--------|------------|-------------|
| send-toast.ps1 | Type, SessionId, TitleB64, BodyB64, ... | Send notification |
| focus-terminal.ps1 | TmuxPane, WindowHandle | Focus window |
| protocol-handler.ps1 | Uri | Handle ccnotify:// click |

#### Output: Windows APIs

| API | Protocol | Description |
|-----|----------|-------------|
| BurntToast | PowerShell Module | Toast notifications |
| user32.dll | P/Invoke | Window management |
| winmm.dll | P/Invoke | Sound playback |
| Registry | PowerShell | URI protocol registration |

### Infrastructure

- **URI Protocol**: `ccnotify://` registered in `HKCU:\Software\Classes\ccnotify`
- **Dependencies**: BurntToast PowerShell module

---

## Container Diagram

```mermaid
C4Container
    title Container Diagram - tmux-cc-notification

    Person(user, "Developer", "Uses Claude Code in tmux")

    System_Boundary(system, "tmux-cc-notification") {
        Container(wsl, "WSL2 Bash Runtime", "Bash, tmux", "Processes Claude Code events, manages state")
        Container(win, "Windows PowerShell Runtime", "PowerShell 7", "Displays notifications, handles clicks")
    }

    System_Ext(claude, "Claude Code", "AI coding assistant")
    System_Ext(toast, "Windows Toast API", "Windows notification system")
    System_Ext(terminal, "Windows Terminal", "Terminal application")

    Rel(user, claude, "Uses")
    Rel(claude, wsl, "Hook events", "JSON/stdin")
    Rel(wsl, win, "Invoke scripts", "pwsh.exe")
    Rel(win, toast, "Display notifications", "BurntToast")
    Rel(toast, win, "Click actions", "ccnotify://")
    Rel(win, terminal, "Focus window", "Win32 API")
    Rel(win, wsl, "Switch pane", "wsl tmux")
```

## Communication Flow

```mermaid
sequenceDiagram
    participant CC as Claude Code
    participant WSL as WSL2 Bash Runtime
    participant PS as Windows PowerShell Runtime
    participant Toast as Windows Toast API
    participant WT as Windows Terminal

    CC->>WSL: Hook event (JSON)
    WSL->>WSL: Process event, update state
    WSL->>PS: pwsh.exe send-toast.ps1
    PS->>Toast: Submit-BTNotification
    Toast-->>User: Display notification

    User->>Toast: Click notification
    Toast->>PS: ccnotify:// URI
    PS->>WT: SetForegroundWindow
    PS->>WSL: wsl tmux select-pane
```

## API Specifications

### WSL → PowerShell Interface

See [apis/wsl-powershell-api.yaml](apis/wsl-powershell-api.yaml)

### URI Protocol Interface

| URI | Format | Description |
|-----|--------|-------------|
| ccnotify:// | `ccnotify://{pane_id}:{hwnd}` | Focus terminal and switch pane |

## Deployment

### Prerequisites

| Requirement | Container | Description |
|-------------|-----------|-------------|
| WSL2 | WSL2 Bash | Windows Subsystem for Linux 2 |
| tmux | WSL2 Bash | Terminal multiplexer |
| jq | WSL2 Bash | JSON processor (optional) |
| PowerShell 7 | Windows PS | PowerShell Core |
| BurntToast | Windows PS | Toast notification module |

### Installation

```bash
# In WSL2
cd tmux-cc-notification
./scripts/install.sh
```

This will:

1. Check dependencies in both containers
2. Register URI protocol in Windows
3. Configure Claude Code hooks
4. Test notification delivery

## Related Documentation

- [Component Index](c4-component.md)
- [System Context](c4-context.md)
