# Dot-source from SSH or the Pi launcher. No prompt/theme/profile output.
$devEnvPreviousErrorAction = $ErrorActionPreference
$devEnvPreviousAutoActivate = $env:CONDA_AUTO_ACTIVATE_BASE
try {
    $ErrorActionPreference = 'Stop'
    . (Join-Path $PSScriptRoot 'node-env.ps1')
    $env:PYTHONUTF8 = '1'

    # Prefer the installation that owns an already activated environment.
    $devEnvCondaCandidates = @(
        $env:CONDA_EXE,
        "$env:USERPROFILE\miniconda3\Scripts\conda.exe",
        "$env:USERPROFILE\anaconda3\Scripts\conda.exe",
        'D:\MiniConda\Scripts\conda.exe',
        'C:\miniconda3\Scripts\conda.exe',
        'C:\ProgramData\miniconda3\Scripts\conda.exe'
    )
    $devEnvCondaExe = $devEnvCondaCandidates | Where-Object {
        $_ -and (Test-Path -LiteralPath $_ -PathType Leaf)
    } | Select-Object -First 1
    if (-not $devEnvCondaExe) { throw 'Conda installation not found.' }

    # Hook initialization must not replace an inherited project environment.
    $env:CONDA_AUTO_ACTIVATE_BASE = 'false'
    $devEnvHook = & $devEnvCondaExe shell.powershell hook
    if ($LASTEXITCODE -ne 0) { throw "Conda hook exited with code $LASTEXITCODE." }
    $devEnvHook | Out-String | Invoke-Expression
    if (-not $env:CONDA_PREFIX) {
        conda activate base
        if ($LASTEXITCODE -ne 0 -or -not $env:CONDA_PREFIX) {
            throw 'Could not activate the default Conda base environment.'
        }
    }
} finally {
    $env:CONDA_AUTO_ACTIVATE_BASE = $devEnvPreviousAutoActivate
    $ErrorActionPreference = $devEnvPreviousErrorAction
    Remove-Variable devEnvPreviousErrorAction, devEnvPreviousAutoActivate, devEnvCondaCandidates, devEnvCondaExe, devEnvHook -ErrorAction SilentlyContinue
}
