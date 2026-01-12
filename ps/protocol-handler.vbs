' protocol-handler.vbs - Launch PowerShell protocol handler without window
' 无窗口启动 PowerShell 协议处理器
' Uses WScript.Shell Run method with 0 to hide window

Set objFSO = CreateObject("Scripting.FileSystemObject")
Set objShell = CreateObject("WScript.Shell")

' Get script directory / 获取脚本目录
strScriptDir = objFSO.GetParentFolderName(WScript.ScriptFullName)
strHandlerScript = strScriptDir & "\protocol-handler.ps1"

' Find PowerShell / 查找 PowerShell
strPwsh = ""
If objFSO.FileExists("C:\Program Files\PowerShell\7\pwsh.exe") Then
    strPwsh = """C:\Program Files\PowerShell\7\pwsh.exe"""
ElseIf objFSO.FileExists("C:\Program Files\PowerShell\7-preview\pwsh.exe") Then
    strPwsh = """C:\Program Files\PowerShell\7-preview\pwsh.exe"""
Else
    strPwsh = """C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"""
End If

' Get URI argument / 获取 URI 参数
strArgs = WScript.Arguments(0)

' Build and run command / 构建并运行命令
strCmd = strPwsh & " -NoProfile -ExecutionPolicy Bypass -File """ & strHandlerScript & """ """ & strArgs & """"
objShell.Run strCmd, 0, False
