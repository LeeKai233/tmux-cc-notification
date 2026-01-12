# send-toast.ps1 - Windows Toast notification sender
# 支持三种通知类型: running, need_input, done
# SEC-2026-0112-0409 H1/H3 修复：Base64 安全传参 + Add-Type 防护

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("running", "need_input", "done", "remove")]
    [string]$Type,

    [string]$SessionId = "default",
    [string]$Title = "Claude Code",
    [string]$Body = "",
    # SEC-2026-0112-0409 H1 修复：新增 Base64 参数（优先使用）
    [string]$TitleB64 = "",
    [string]$BodyB64 = "",
    [string]$TmuxInfoB64 = "",
    [string]$AppLogo = "",
    [string]$HeroImage = "",
    [string]$SoundPath = "",
    [int]$SoundRepeat = 1,
    [string]$UpdateSame = "1",
    [string]$TmuxInfo = ""
)

# SEC-2026-0112-0409 H1 修复：Base64 解码函数
function Decode-Base64 {
    param([string]$Encoded)
    if ([string]::IsNullOrEmpty($Encoded)) { return "" }
    try {
        [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Encoded))
    } catch {
        ""
    }
}

# SEC-2026-0112-0409 H1 修复：优先使用 Base64 参数
if ($TitleB64) { $Title = Decode-Base64 $TitleB64 }
if ($BodyB64) { $Body = Decode-Base64 $BodyB64 }
if ($TmuxInfoB64) { $TmuxInfo = Decode-Base64 $TmuxInfoB64 }

# 确保 BurntToast 模块已加载
if (-not (Get-Module -Name BurntToast -ErrorAction SilentlyContinue)) {
    Import-Module BurntToast -ErrorAction SilentlyContinue
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$FocusScript = Join-Path $ScriptDir "focus-terminal.ps1"

# 生成通知 Tag
function Get-NotificationTag {
    param([string]$Type, [string]$SessionId)
    return "cc-$Type-$SessionId"
}

# 移除通知
function Remove-Notification {
    param([string]$Tag)
    Remove-BTNotification -UniqueIdentifier $Tag -ErrorAction SilentlyContinue
}

# 发送通知
function Send-Notification {
    param(
        [string]$Tag,
        [string]$Title,
        [string]$Body,
        [string]$AppLogo,
        [string]$HeroImage,
        [string]$SoundPath,
        [int]$SoundRepeat,
        [bool]$UpdateSame,
        [string]$TmuxInfo
    )

    # 构建文本内容
    $TextElements = @()
    if ($Title) {
        $TextElements += New-BTText -Text $Title
    }
    if ($Body) {
        $TextElements += New-BTText -Text $Body
    }

    # 构建绑定
    $BindingParams = @{
        Children = $TextElements
    }

    # AppLogo
    if ($AppLogo -and (Test-Path $AppLogo -ErrorAction SilentlyContinue)) {
        $BindingParams.AppLogoOverride = New-BTImage -Source $AppLogo -AppLogoOverride -Crop Circle
    }

    # HeroImage
    if ($HeroImage -and (Test-Path $HeroImage -ErrorAction SilentlyContinue)) {
        $BindingParams.HeroImage = New-BTImage -Source $HeroImage -HeroImage
    }

    $Binding = New-BTBinding @BindingParams
    $Visual = New-BTVisual -BindingGeneric $Binding

    # 构建点击动作 - 使用 ccnotify:// 协议
    $Actions = $null
    if ($TmuxInfo) {
        # TmuxInfo 格式: pane_id:hwnd:tab_index
        $Parts = $TmuxInfo -split ":"
        $TmuxPane = $Parts[0]
        $WindowHandle = if ($Parts.Count -ge 2) { $Parts[1] } else { "" }
        $TabIndex = if ($Parts.Count -ge 3) { $Parts[2] } else { "" }

        # 创建点击按钮，使用自定义 URI 协议
        $Uri = "ccnotify://${TmuxPane}:${WindowHandle}:${TabIndex}"
        $Button = New-BTButton -Content "Switch to Task" -Arguments $Uri -ActivationType Protocol
        $Actions = New-BTAction -Buttons $Button
    }

    # 构建通知内容
    $ContentParams = @{
        Visual = $Visual
    }
    if ($Actions) {
        $ContentParams.Actions = $Actions
    }

    # 设置通知持续时间
    $ContentParams.Duration = "Short"

    $Content = New-BTContent @ContentParams

    # 如果需要更新同一条通知，先删除旧的
    if ($UpdateSame) {
        Remove-BTNotification -UniqueIdentifier $Tag -ErrorAction SilentlyContinue
    }

    # 提交通知
    Submit-BTNotification -Content $Content -UniqueIdentifier $Tag

    # 使用 Windows API 播放自定义声音
    # SEC-2026-0112-0409 H3 修复：单引号 here-string + 幂等加载
    if ($SoundPath -and (Test-Path $SoundPath -ErrorAction SilentlyContinue)) {
        if (-not ("WinSound" -as [type])) {
            Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class WinSound {
    [DllImport("winmm.dll", SetLastError = true)]
    public static extern bool PlaySound(string pszSound, IntPtr hmod, uint fdwSound);
    public const uint SND_FILENAME = 0x00020000;
    public const uint SND_SYNC = 0x0000;
}
'@ -ErrorAction SilentlyContinue
        }

        for ($i = 0; $i -lt $SoundRepeat; $i++) {
            [WinSound]::PlaySound($SoundPath, [IntPtr]::Zero, [WinSound]::SND_FILENAME -bor [WinSound]::SND_SYNC)
            if ($i -lt $SoundRepeat - 1) { Start-Sleep -Milliseconds 300 }
        }
    }
}

# 主逻辑
switch ($Type) {
    "running" {
        $Tag = Get-NotificationTag "running" $SessionId
        $UpdateSameBool = $UpdateSame -eq "1"
        Send-Notification -Tag $Tag -Title $Title -Body $Body `
            -AppLogo $AppLogo -SoundPath $SoundPath -SoundRepeat $SoundRepeat `
            -UpdateSame $UpdateSameBool -TmuxInfo $TmuxInfo
    }
    "need_input" {
        $Tag = Get-NotificationTag "input" $SessionId
        # need_input 每次新增，使用时间戳区分
        $Tag = "$Tag-$(Get-Date -Format 'HHmmss')"
        Send-Notification -Tag $Tag -Title $Title -Body $Body `
            -AppLogo $AppLogo -SoundPath $SoundPath -SoundRepeat $SoundRepeat `
            -UpdateSame $false -TmuxInfo $TmuxInfo
    }
    "done" {
        # 先清理进行中通知
        $RunningTag = Get-NotificationTag "running" $SessionId
        Remove-Notification -Tag $RunningTag

        $Tag = Get-NotificationTag "done" $SessionId
        Send-Notification -Tag $Tag -Title $Title -Body $Body `
            -AppLogo $AppLogo -HeroImage $HeroImage -SoundPath $SoundPath `
            -SoundRepeat $SoundRepeat -UpdateSame $true -TmuxInfo $TmuxInfo
    }
    "remove" {
        # 移除所有该 session 的通知
        Remove-Notification -Tag (Get-NotificationTag "running" $SessionId)
        Remove-Notification -Tag (Get-NotificationTag "done" $SessionId)
        # input 通知带时间戳，需要遍历移除
        Get-BTHistory | Where-Object { $_.Tag -like "cc-input-$SessionId*" } | ForEach-Object {
            Remove-BTNotification -Tag $_.Tag -ErrorAction SilentlyContinue
        }
    }
}
