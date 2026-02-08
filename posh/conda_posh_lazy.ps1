# separate conda initialization (lazy) from profile.ps1 for speed
$condaExe = "D:\MiniConda\Scripts\conda.exe"
if (-not (Test-Path $condaExe)) {
    Write-Error "conda.exe not found at $condaExe"
    return
}

# initialize conda hook
(& $condaExe shell.powershell hook) | Out-String | Where-Object { $_ } | Invoke-Expression
Write-Output "conda initialized"  # print a message

# continue this command arguments if there are any (e.g., conda activate <env>)
if ($args.Count -gt 0) {
    & conda @args
}
