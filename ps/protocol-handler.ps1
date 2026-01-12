# protocol-handler.ps1 - ccnotify:// URI protocol handler
# 接收 URI 参数并调用 focus-terminal.ps1
# SEC-2026-0112-0409 H4 修复：TmuxPane 格式校验

param([string]$Uri)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# SEC-2026-0112-0409 H4 修复：校验 TmuxPane 格式
# 仅允许：%数字、@数字、session:window.pane、纯字母数字
function Validate-TmuxPane {
    param([string]$Pane)
    if ([string]::IsNullOrEmpty($Pane)) {
        return $null
    }
    # 允许的格式：%123, @123, session:1.2, session_name, session-name
    if ($Pane -match '^[%@]?\d+$|^[\w-]+:\d+\.\d+$|^[\w-]+$') {
        return $Pane
    }
    Write-Warning "Invalid TmuxPane format: $Pane"
    return $null
}

# Parse URI: ccnotify://pane_id:hwnd / 解析 URI
$Data = $Uri -replace "ccnotify://", "" -replace "/$", ""
$Parts = $Data -split ":"

$TmuxPane = Validate-TmuxPane $Parts[0]
$WindowHandle = if ($Parts.Count -ge 2) { $Parts[1] } else { "" }

# 仅在 TmuxPane 有效时调用
if ($TmuxPane) {
    & "$ScriptDir\focus-terminal.ps1" -TmuxPane $TmuxPane -WindowHandle $WindowHandle
}
