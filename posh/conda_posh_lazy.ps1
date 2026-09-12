# separate conda initialization (lazy) from profile.ps1 for speed
$condaCandidates = @(
    "$env:USERPROFILE\miniconda3",
    "$env:USERPROFILE\anaconda3",
    "$env:USERPROFILE\Miniconda3",
    "$env:USERPROFILE\Anaconda3",
    "D:\MiniConda",
    "C:\miniconda3",
    "C:\ProgramData\miniconda3"
)
$condaExe = $null
foreach ($root in $condaCandidates) {
    $exe = Join-Path $root 'Scripts\conda.exe'
    if (Test-Path -LiteralPath $exe) {
        $condaExe = $exe
        break
    }
}
if (-not $condaExe) {
    Write-Warning "conda not found (searched common install paths); skipping. If you have switched to uv, this alias is simply unused."
    return
}

# initialize conda hook
(& $condaExe shell.powershell hook) | Out-String | Where-Object { $_ } | Invoke-Expression
Write-Output "conda initialized"  # print a message

# continue this command arguments if there are any (e.g., conda activate <env>)
if ($args.Count -gt 0) {
    & conda @args
}
