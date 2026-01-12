# focus-terminal.ps1 - Focus Windows Terminal and switch tmux pane
# 聚焦 Windows Terminal 并切换 tmux pane - 通知点击时调用

param(
    [string]$TmuxPane = "",
    [string]$WindowHandle = ""
)

# 添加 Win32 API
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class User32 {
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")]
    public static extern bool IsIconic(IntPtr hWnd);
    [DllImport("user32.dll")]
    public static extern bool IsWindow(IntPtr hWnd);
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
    [DllImport("kernel32.dll")]
    public static extern uint GetCurrentThreadId();
    [DllImport("user32.dll")]
    public static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);
    [DllImport("user32.dll")]
    public static extern bool BringWindowToTop(IntPtr hWnd);
}
"@

$hwnd = [IntPtr]::Zero

# Use provided window handle / 使用传入的窗口句柄
if ($WindowHandle) {
    $hwnd = [IntPtr]::new([long]$WindowHandle)
    if (-not [User32]::IsWindow($hwnd)) { $hwnd = [IntPtr]::Zero }
}

# Fallback: find Windows Terminal process / 回退：查找 Windows Terminal 进程
if ($hwnd -eq [IntPtr]::Zero) {
    $wt = Get-Process WindowsTerminal -ErrorAction SilentlyContinue |
          Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero } |
          Select-Object -First 1
    if ($wt) { $hwnd = $wt.MainWindowHandle }
}

if ($hwnd -ne [IntPtr]::Zero) {
    # Restore if minimized / 如果窗口最小化，先恢复
    if ([User32]::IsIconic($hwnd)) {
        [User32]::ShowWindow($hwnd, 9)  # SW_RESTORE
    }

    # Use AttachThreadInput to bypass foreground restriction
    # 使用 AttachThreadInput 绕过前台限制
    $foregroundHwnd = [User32]::GetForegroundWindow()
    $foregroundPid = 0
    $foregroundThread = [User32]::GetWindowThreadProcessId($foregroundHwnd, [ref]$foregroundPid)
    $currentThread = [User32]::GetCurrentThreadId()

    [User32]::AttachThreadInput($currentThread, $foregroundThread, $true)
    [User32]::BringWindowToTop($hwnd)
    [User32]::SetForegroundWindow($hwnd)
    [User32]::AttachThreadInput($currentThread, $foregroundThread, $false)

    # Switch tmux pane / 切换 tmux pane
    if ($TmuxPane) {
        wsl tmux select-pane -t "$TmuxPane" 2>$null
    }
}
