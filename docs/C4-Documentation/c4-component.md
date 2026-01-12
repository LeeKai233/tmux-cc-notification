# C4 Component Index

## System Components

| Component | Description | Documentation |
|-----------|-------------|---------------|
| Hook Event Handler | Processes Claude Code lifecycle events | [c4-component-hook-handler.md](c4-component-hook-handler.md) |
| Windows Notification | Sends Windows Toast notifications | [c4-component-windows-notification.md](c4-component-windows-notification.md) |
| Configuration | Manages application settings | [c4-component-configuration.md](c4-component-configuration.md) |
| Installation & Testing | Setup and verification scripts | [c4-component-installation.md](c4-component-installation.md) |

## Component Relationships Diagram

```mermaid
C4Component
    title Component Diagram - tmux-cc-notification

    Container_Boundary(wsl, "WSL2 (Bash)") {
        Component(hooks, "Hook Event Handler", "Bash", "Processes Claude Code events")
        Component(config, "Configuration", "Bash/TOML", "Manages settings")
        Component(install, "Installation & Testing", "Bash", "Setup and verification")
    }

    Container_Boundary(win, "Windows (PowerShell)") {
        Component(notify, "Windows Notification", "PowerShell", "Toast notifications")
    }

    System_Ext(claude, "Claude Code", "AI coding assistant")
    System_Ext(toast, "Windows Toast API", "Notification system")
    System_Ext(tmux, "tmux", "Terminal multiplexer")

    Rel(claude, hooks, "Hook events", "JSON/stdin")
    Rel(hooks, config, "Reads settings")
    Rel(hooks, notify, "Send notification", "pwsh.exe")
    Rel(notify, toast, "Display toast", "BurntToast")
    Rel(notify, tmux, "Switch pane", "wsl tmux")
    Rel(install, hooks, "Configures")
    Rel(install, notify, "Registers protocol")
```

## Data Flow

```mermaid
flowchart LR
    subgraph Input
        CC[Claude Code]
        User[User Config]
    end

    subgraph Processing
        Hooks[Hook Event Handler]
        Config[Configuration]
    end

    subgraph Output
        Notify[Windows Notification]
        State[State Files]
    end

    subgraph External
        Toast[Windows Toast]
        Terminal[Windows Terminal]
    end

    CC -->|JSON events| Hooks
    User -->|TOML file| Config
    Config -->|env vars| Hooks
    Hooks -->|notification request| Notify
    Hooks -->|persist| State
    Notify -->|display| Toast
    Toast -->|click| Notify
    Notify -->|focus| Terminal
```

## Component Dependencies Matrix

| Component | Hook Handler | Win Notification | Configuration | Installation |
|-----------|:------------:|:----------------:|:-------------:|:------------:|
| Hook Event Handler | - | Uses | Uses | - |
| Windows Notification | - | - | - | - |
| Configuration | - | - | - | - |
| Installation & Testing | Configures | Registers | Uses | - |

## Code-Level Documentation Index

| Directory | Documentation | Description |
|-----------|---------------|-------------|
| lib/ | [c4-code-lib.md](c4-code-lib.md) | Core library modules |
| hooks/ | [c4-code-hooks.md](c4-code-hooks.md) | Claude Code hook scripts |
| ps/ | [c4-code-ps.md](c4-code-ps.md) | PowerShell scripts |
| scripts/ | [c4-code-scripts.md](c4-code-scripts.md) | Installation scripts |
| (root) | [c4-code-root.md](c4-code-root.md) | Configuration loader |
