' protocol-handler.vbs - Launch PowerShell protocol handler without window
' Uses WScript.Shell Run method with 0 to hide window

Set objFSO = CreateObject("Scripting.FileSystemObject")
Set objShell = CreateObject("WScript.Shell")

' Get script directory
strScriptDir = objFSO.GetParentFolderName(WScript.ScriptFullName)
strHandlerScript = strScriptDir & "\protocol-handler.ps1"

' Find PowerShell
strPwsh = ""
If objFSO.FileExists("C:\Program Files\PowerShell\7\pwsh.exe") Then
    strPwsh = """C:\Program Files\PowerShell\7\pwsh.exe"""
ElseIf objFSO.FileExists("C:\Program Files\PowerShell\7-preview\pwsh.exe") Then
    strPwsh = """C:\Program Files\PowerShell\7-preview\pwsh.exe"""
Else
    strPwsh = """C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"""
End If

' Get URI argument
If WScript.Arguments.Count = 0 Then
    WScript.Quit 1
End If
strArgs = WScript.Arguments(0) & ""

If Len(strArgs) = 0 Then
    WScript.Quit 1
End If

' Build and run command
strCmd = strPwsh & " -NoProfile -ExecutionPolicy Bypass -File """ & strHandlerScript & """ """ & strArgs & """"
objShell.Run strCmd, 0, False
