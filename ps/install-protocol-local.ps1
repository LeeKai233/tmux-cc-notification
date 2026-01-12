# install-protocol-local.ps1 - Install protocol handler to local Windows path
# 将协议处理器安装到本地 Windows 路径，避免 UNC 路径中 .claude 的问题

param([switch]$Force, [switch]$Uninstall)

$LocalDir = "$env:LOCALAPPDATA\ccnotify"
$WslScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if ($Uninstall) {
    if (Test-Path "HKCU:\Software\Classes\ccnotify") {
        Remove-Item -Path "HKCU:\Software\Classes\ccnotify" -Recurse -Force
        Write-Information "Protocol unregistered." -InformationAction Continue
    }
    if (Test-Path $LocalDir) {
        Remove-Item -Path $LocalDir -Recurse -Force
        Write-Information "Local scripts removed." -InformationAction Continue
    }
    exit 0
}

# Create local directory
if (-not (Test-Path $LocalDir)) {
    New-Item -ItemType Directory -Path $LocalDir -Force | Out-Null
}

# Copy scripts to local path
$FilesToCopy = @("protocol-handler.vbs", "protocol-handler.ps1", "focus-terminal.ps1")
foreach ($f in $FilesToCopy) {
    $src = Join-Path $WslScriptDir $f
    $dst = Join-Path $LocalDir $f
    if (Test-Path $src) {
        Copy-Item -Path $src -Destination $dst -Force
        Write-Information "Copied: $f" -InformationAction Continue
    }
}

$VbsPath = Join-Path $LocalDir "protocol-handler.vbs"
$RegPath = "HKCU:\Software\Classes\ccnotify"

if (-not $Force) {
    Write-Information "This will register ccnotify:// protocol using local path:" -InformationAction Continue
    Write-Information "  $VbsPath" -InformationAction Continue
    Write-Information "" -InformationAction Continue
    $confirm = Read-Host "Continue? (y/N)"
    if ($confirm -ne 'y' -and $confirm -ne 'Y') {
        Write-Information "Aborted." -InformationAction Continue
        exit 0
    }
}

# Register protocol
New-Item -Path $RegPath -Force | Out-Null
Set-ItemProperty -Path $RegPath -Name "(Default)" -Value "URL:CC Notify Protocol"
Set-ItemProperty -Path $RegPath -Name "URL Protocol" -Value ""
New-Item -Path "$RegPath\shell\open\command" -Force | Out-Null
$Command = "wscript.exe `"$VbsPath`" `"%1`""
Set-ItemProperty -Path "$RegPath\shell\open\command" -Name "(Default)" -Value $Command

Write-Information "" -InformationAction Continue
Write-Information "Registration complete!" -InformationAction Continue
Write-Information "Handler: $VbsPath" -InformationAction Continue
Write-Information "" -InformationAction Continue
Write-Information "Test: Start-Process 'ccnotify://test:123:0'" -InformationAction Continue
