' ============================================================
'  MicroTyk.vbs - starter script (hidden window)
'  Launches MicroTyk.ps1 without visible PowerShell window
' ============================================================
Set objShell = CreateObject("WScript.Shell")
strScript = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName) & "\MicroTyk.ps1"
objShell.Run "powershell.exe -NoProfile -WindowStyle Hidden -File """ & strScript & """", 0, False
