# install-protocol.ps1 - Register ccnotify:// URI protocol
# 注册 ccnotify:// URI 协议 - 运行一次即可
# SEC-2026-0112-0409 M4：添加路径验证、确认机制、卸载功能

param(
    [switch]$Force,
    [switch]$Uninstall,
    [string]$Lang
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$VbsPath = Join-Path $ScriptDir "protocol-handler.vbs"
$RegPath = "HKCU:\Software\Classes\ccnotify"

# Detect language from Windows system locale or use provided Lang parameter
function Get-UILang {
    if ($Lang) { return $Lang }
    $locale = (Get-WinSystemLocale).Name
    if ($locale -match '^(zh|ja|ko)') { return "zh" }
    return "en"
}

$UILang = Get-UILang

# Messages
if ($UILang -eq "zh") {
    $MSG_UNREGISTERED = "协议已成功注销。"
    $MSG_NOT_REGISTERED = "协议未注册。"
    $MSG_HANDLER_NOT_FOUND = "错误：处理器脚本未找到："
    $MSG_HANDLER_WRONG_DIR = "错误：处理器脚本必须在"
    $MSG_PWSH_NOT_FOUND = "错误：未找到 PowerShell 7。请从 https://github.com/PowerShell/PowerShell 安装"
    $MSG_REGISTERING = "正在注册 ccnotify:// 协议..."
    $MSG_HANDLER = "处理器："
    $MSG_POWERSHELL = "PowerShell："
    $MSG_CONFIRM_PROMPT = "这将修改 Windows 注册表以注册 ccnotify:// 协议。"
    $MSG_REG_PATH = "注册表路径："
    $MSG_CONTINUE = "继续？(y/N)"
    $MSG_ABORTED = "已取消。"
    $MSG_COMPLETE = "注册完成！"
    $MSG_TEST_CMD = "测试命令："
} else {
    $MSG_UNREGISTERED = "Protocol unregistered successfully."
    $MSG_NOT_REGISTERED = "Protocol not registered."
    $MSG_HANDLER_NOT_FOUND = "Error: Handler script not found:"
    $MSG_HANDLER_WRONG_DIR = "Error: Handler script must be in"
    $MSG_PWSH_NOT_FOUND = "Error: PowerShell 7 not found. Please install from https://github.com/PowerShell/PowerShell"
    $MSG_REGISTERING = "Registering ccnotify:// protocol..."
    $MSG_HANDLER = "Handler:"
    $MSG_POWERSHELL = "PowerShell:"
    $MSG_CONFIRM_PROMPT = "This will modify Windows Registry to register ccnotify:// protocol."
    $MSG_REG_PATH = "Registry path:"
    $MSG_CONTINUE = "Continue? (y/N)"
    $MSG_ABORTED = "Aborted."
    $MSG_COMPLETE = "Registration complete!"
    $MSG_TEST_CMD = "Test command:"
}

# SEC-2026-0112-0409 M4：卸载功能
if ($Uninstall) {
    if (Test-Path $RegPath) {
        Remove-Item -Path $RegPath -Recurse -Force
        Write-Host $MSG_UNREGISTERED -ForegroundColor Green
    } else {
        Write-Host $MSG_NOT_REGISTERED
    }
    exit 0
}

# SEC-2026-0112-0409 M4：验证 VBS 处理器存在
if (-not (Test-Path $VbsPath)) {
    Write-Host "$MSG_HANDLER_NOT_FOUND $VbsPath" -ForegroundColor Red
    exit 1
}

# SEC-2026-0112-0409 M4：验证路径在预期目录内
$ResolvedVbsPath = Resolve-Path $VbsPath -ErrorAction SilentlyContinue
if ($ResolvedVbsPath) {
    $ActualDir = Split-Path -Parent $ResolvedVbsPath.Path
    if ($ActualDir -ne $ScriptDir) {
        Write-Host "$MSG_HANDLER_WRONG_DIR $ScriptDir" -ForegroundColor Red
        exit 1
    }
}

# Auto-detect PowerShell path / 自动检测 PowerShell 路径
function Find-PowerShell {
    $candidates = @(
        "C:\Program Files\PowerShell\7\pwsh.exe",
        "C:\Program Files\PowerShell\7-preview\pwsh.exe"
    )
    foreach ($p in $candidates) {
        if (Test-Path $p) { return $p }
    }
    return $null
}

$PwshPath = Find-PowerShell
if (-not $PwshPath) {
    Write-Host $MSG_PWSH_NOT_FOUND -ForegroundColor Red
    exit 1
}

Write-Host $MSG_REGISTERING
Write-Host "$MSG_HANDLER $VbsPath"
Write-Host "$MSG_POWERSHELL $PwshPath"

# SEC-2026-0112-0409 M4：用户确认机制
if (-not $Force) {
    Write-Host ""
    Write-Host $MSG_CONFIRM_PROMPT -ForegroundColor Yellow
    Write-Host "$MSG_REG_PATH $RegPath"
    Write-Host ""
    $confirm = Read-Host $MSG_CONTINUE
    if ($confirm -ne 'y' -and $confirm -ne 'Y') {
        Write-Host $MSG_ABORTED
        exit 0
    }
}

# Create protocol registry key / 创建协议注册表项
New-Item -Path $RegPath -Force | Out-Null
Set-ItemProperty -Path $RegPath -Name "(Default)" -Value "URL:CC Notify Protocol"
Set-ItemProperty -Path $RegPath -Name "URL Protocol" -Value ""

# Create shell\open\command subkey / 创建 shell\open\command 子项
New-Item -Path "$RegPath\shell\open\command" -Force | Out-Null

# Set command - use VBS wrapper for windowless execution
# 设置命令 - 使用 VBS 包装器实现无窗口执行
$Command = "wscript.exe `"$VbsPath`" `"%1`""
Set-ItemProperty -Path "$RegPath\shell\open\command" -Name "(Default)" -Value $Command

Write-Host ""
Write-Host $MSG_COMPLETE -ForegroundColor Green
Write-Host ""
Write-Host "$MSG_TEST_CMD Start-Process 'ccnotify://test:123:0'"
