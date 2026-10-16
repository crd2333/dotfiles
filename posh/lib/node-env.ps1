# nvm / system npm
if (Get-Command nvm -ErrorAction SilentlyContinue) {
    if (Test-Path Env:\NPM_CONFIG_PREFIX) {
        Remove-Item Env:\NPM_CONFIG_PREFIX
    }
} else {  # use system npm, keep global packages under a NodeJS dir
    # multi-drive machine keeps D:\NodeJS; single-drive machines use $HOME\NodeJS
    $nodeBin = if (Test-Path -LiteralPath 'D:\NodeJS') { 'D:\NodeJS' } else { "$HOME\NodeJS" }
    if (($env:PATH -split ';') -notcontains $nodeBin) {
        $env:PATH = "$nodeBin;$env:PATH"
    }
    $env:NPM_CONFIG_PREFIX = "$nodeBin\npm_global"
    $npmGlobalBin = "$nodeBin\npm_global"
    if (($env:PATH -split ';') -notcontains $npmGlobalBin) {
        $env:PATH = "$npmGlobalBin;$env:PATH"
    }
    $npmGlobalModules = "$nodeBin\npm_global\node_modules"
    if (-not $env:NODE_PATH -or (($env:NODE_PATH -split ';') -notcontains $npmGlobalModules)) {
        if ($env:NODE_PATH) {
            $env:NODE_PATH = "$npmGlobalModules;$env:NODE_PATH"
        } else {
            $env:NODE_PATH = $npmGlobalModules
        }
    }
}
