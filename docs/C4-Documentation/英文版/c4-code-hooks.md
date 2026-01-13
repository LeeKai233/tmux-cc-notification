# C4 Code-Level Documentation: hooks/

## Overview

- **Name**: Claude Code Hook Scripts
- **Description**: Event handler scripts that integrate with Claude Code's hook system
- **Location**: [hooks/](../../../hooks/)
- **Language**: Bash (Shell Script)
- **Purpose**: Respond to Claude Code lifecycle events (task start, tool use, input required, task end) to trigger notifications and manage state

## Code Elements

### on-task-start.sh

**Location**: [hooks/on-task-start.sh](../../../hooks/on-task-start.sh)

**Hook Type**: `UserPromptSubmit`

**Purpose**: Called when user submits a prompt to Claude Code. Initializes task state and starts background monitor.

| Function/Section | Description |
|------------------|-------------|
| Input parsing | Reads JSON from stdin, validates with `validate_json` |
| Session ID extraction | Parses `session_id` from JSON input |
| State initialization | Calls `set_task_start()` to record start time, prompt, tmux info |
| HWND capture | Captures Windows Terminal window handle via PowerShell |
| Monitor startup | Starts `periodic-monitor.sh` as background process |

**Flow**:

```txt
stdin (JSON) → validate_json → parse_session_id → set_task_start
                                                 → capture HWND
                                                 → start periodic-monitor.sh
```

**Security Features**:

- SEC-2026-0112-0409 H2: Input validation
- SEC-2026-0112-0409 H3: Add-Type protection for HWND capture
- SEC-2026-0112-0409 M3: Fail-fast JSON validation

### on-tool-use.sh

**Location**: [hooks/on-tool-use.sh](../../../hooks/on-tool-use.sh)

**Hook Type**: `PreToolUse`

**Purpose**: Called before each tool invocation. Clears waiting-input state and updates activity timestamp.

| Function/Section | Description |
|------------------|-------------|
| Input parsing | Reads JSON from stdin, validates structure |
| Session ID extraction | Parses `session_id` from JSON |
| State update | Clears `waiting-input` flag if set |
| Activity tracking | Updates `last-tool-time` timestamp |

**Flow**:

```txt
stdin (JSON) → validate_json → parse_session_id → clear_waiting_input
                                                → update_last_tool_time
```

**Security Features**:

- SEC-2026-0112-0409 H2: Input validation
- SEC-2026-0112-0409 M3: Fail-fast JSON validation

### on-need-input.sh

**Location**: [hooks/on-need-input.sh](../../../hooks/on-need-input.sh)

**Hook Type**: `Notification` (matcher: `permission_prompt|elicitation_dialog`)

**Purpose**: Called when Claude Code needs user permission or input. Sends immediate notification.

| Function/Section | Description |
|------------------|-------------|
| Input parsing | Reads JSON from stdin, validates structure |
| Duplicate check | Skips if already in waiting state |
| State update | Sets `waiting-input` flag |
| Suppression check | Checks if user is viewing the pane |
| Notification | Sends "need_input" toast via PowerShell |

**Flow**:

```txt
stdin (JSON) → validate_json → parse_session_id → is_waiting_input?
                                                → set_waiting_input
                                                → should_suppress?
                                                → send_notification("need_input")
```

**Security Features**:

- SEC-2026-0112-0409 H1: Base64 safe parameter passing
- SEC-2026-0112-0409 H2: Input validation
- SEC-2026-0112-0409 M2: Configurable execution policy
- SEC-2026-0112-0409 M3: Fail-fast JSON validation

### on-task-end.sh

**Location**: [hooks/on-task-end.sh](../../../hooks/on-task-end.sh)

**Hook Type**: `Stop`

**Purpose**: Called when Claude Code task completes. Sends completion notification and cleans up state.

| Function/Section | Description |
|------------------|-------------|
| Input parsing | Reads JSON from stdin, validates structure |
| Task check | Verifies task is actually running |
| Info gathering | Gets elapsed time, prompt, session name |
| Suppression check | Checks if user is viewing the pane |
| Notification | Sends "done" toast with hero image |
| Cleanup | Removes state directory and kills monitor |

**Flow**:

```txt
stdin (JSON) → validate_json → parse_session_id → is_task_running?
                                                → get_elapsed_minutes
                                                → should_suppress?
                                                → send_notification("done")
                                                → cleanup_state
```

**Security Features**:

- SEC-2026-0112-0409 H1: Base64 safe parameter passing
- SEC-2026-0112-0409 H2: Input validation
- SEC-2026-0112-0409 M2: Configurable execution policy
- SEC-2026-0112-0409 M3: Fail-fast JSON validation

## Dependencies

### Internal Dependencies

All hooks depend on:

- `config.sh` - Configuration loading
- `lib/state.sh` - State management
- `lib/json.sh` - JSON parsing
- `lib/log.sh` - Debug logging

Additional dependencies:

- `on-task-start.sh` → `lib/pwsh.sh`, `lib/audit.sh`
- `on-need-input.sh` → `lib/suppress.sh`, `lib/pwsh.sh`, `lib/sanitize.sh`
- `on-task-end.sh` → `lib/suppress.sh`, `lib/pwsh.sh`, `lib/sanitize.sh`, `lib/audit.sh`

### External Dependencies

- Claude Code hook system (provides JSON input via stdin)
- tmux (for pane/session info)
- PowerShell 7 (for Windows notifications)

## Relationships

```mermaid
sequenceDiagram
    participant CC as Claude Code
    participant Start as on-task-start.sh
    participant Tool as on-tool-use.sh
    participant Input as on-need-input.sh
    participant End as on-task-end.sh
    participant Monitor as periodic-monitor.sh
    participant State as State Files
    participant PS as PowerShell

    CC->>Start: UserPromptSubmit (JSON)
    Start->>State: set_task_start()
    Start->>Monitor: spawn background

    loop Every tool use
        CC->>Tool: PreToolUse (JSON)
        Tool->>State: update_last_tool_time()
    end

    opt Permission needed
        CC->>Input: Notification (JSON)
        Input->>State: set_waiting_input()
        Input->>PS: send toast
    end

    loop Every 30s
        Monitor->>State: check state
        Monitor->>PS: send periodic toast
    end

    CC->>End: Stop (JSON)
    End->>PS: send done toast
    End->>State: cleanup_state()
    End->>Monitor: kill
```

## Hook Configuration

Hooks are configured in `~/.claude/settings.json`:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      { "hooks": [{ "type": "command", "command": "/path/to/hooks/on-task-start.sh" }] }
    ],
    "Notification": [
      { "matcher": "permission_prompt|elicitation_dialog",
        "hooks": [{ "type": "command", "command": "/path/to/hooks/on-need-input.sh" }] }
    ],
    "PreToolUse": [
      { "hooks": [{ "type": "command", "command": "/path/to/hooks/on-tool-use.sh" }] }
    ],
    "Stop": [
      { "hooks": [{ "type": "command", "command": "/path/to/hooks/on-task-end.sh" }] }
    ]
  }
}
```
