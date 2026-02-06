# separate conda initialize from profile.ps1 for speed
#region conda initialize
# !! Contents within this block are managed by 'conda init' !!
If (Test-Path "D:\MiniConda\Scripts\conda.exe") {
    (& "D:\MiniConda\Scripts\conda.exe" "shell.powershell" "hook") | Out-String | ?{$_} | Invoke-Expression
}
#endregion