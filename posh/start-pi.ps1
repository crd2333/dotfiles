# Keep raw $args: Pi options such as --mode and --help belong to Pi, not PowerShell.
try {
    . (Join-Path $PSScriptRoot 'lib\dev-env.ps1')
    $piShim = (Get-Command pi.cmd -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
    $piPackageRoot = Join-Path (Split-Path $piShim) 'node_modules\@earendil-works\pi-coding-agent'
    $piPackage = Get-Content -Raw -LiteralPath (Join-Path $piPackageRoot 'package.json') -ErrorAction Stop | ConvertFrom-Json
    $piEntry = Join-Path $piPackageRoot $piPackage.bin.pi
    if (-not (Test-Path -LiteralPath $piEntry -PathType Leaf)) {
        throw "Pi entry point not found: $piEntry"
    }
    $piNode = (Get-Command node.exe -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
} catch {
    [Console]::Error.WriteLine('Pi environment initialization failed: ' + $_.Exception.Message)
    exit 126
}

# Bypass the npm .cmd shim to preserve spaces, quotes and RPC stdio.
& $piNode $piEntry @args
exit $LASTEXITCODE
