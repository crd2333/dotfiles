Import-Module DirColors
Import-Module PSReadLine  # 这个工具主要做命令提示管理等操作，默认集成在了 PowerShell 中，不需要安装
if ($Host.Name -eq 'ConsoleHost' -and -not [Console]::IsInputRedirected -and
    -not [Console]::IsOutputRedirected -and $Host.UI.SupportsVirtualTerminal) {
    Set-PSReadLineOption -PredictionSource History # 设置预测文本来源为历史记录
}
Set-PSReadlineKeyHandler -Chord Tab -Function MenuComplete # 类似 zsh 的带菜单补全
Set-PSReadlineKeyHandler -Chord Ctrl+x,Ctrl+X -Function DeleteLine # 清空整行

Set-PSReadLineOption -Colors @{
    Parameter        = 'Green'
    InlinePrediction = "#438a55"
}


# 别名设置
set-alias -Name cl -Value clear
set-alias -Name vi -Value vim
set-alias -Name conda -Value (Join-Path $HOME 'dotfiles\posh\conda_posh_lazy.ps1') # lazy load conda initialization
set-alias -Name cc -Value claude
set-alias -Name cx -Value codex


# Linux-like cmds
. (Join-Path $HOME 'dotfiles\posh\linux_like_cmds.ps1')


# 函数设置
function work {
    Set-Location -Path ([Environment]::GetFolderPath('MyDocuments'))
}
function countSize {
    Get-ChildItem -Directory | ForEach-Object {
        $size = (Get-ChildItem $_.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        [PSCustomObject]@{
            Folder = $_.Name
            "Size(GB)" = "{0:N2}" -f ($size / 1GB)
        }
    } | Sort-Object -Property "Size(GB)" -Descending
}


# 网络代理设置（system_proxy / unset_proxy / test_proxy / clean_proxy）
. (Join-Path $HOME 'dotfiles\posh\lib\proxy.ps1')


$ompTheme = Join-Path $HOME 'dotfiles\posh\tokyo_modified.omp.json'
oh-my-posh init pwsh --config $ompTheme | Invoke-Expression  # 设置主题，可以去 https://ohmyposh.dev/docs/themes 找


# opencode with proxy
function opencode {
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [Switch]$NoProxy,
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$RemainingArgs
    )

    process {
        $help_re = '^(help|-h|--help|version|-v|--version|completion|models|providers|auth|agent|mcp|acp|stats|session|export|import|github|db|uninstall|debug|attach)$'

        $first_arg = if ($RemainingArgs) { $RemainingArgs[0] } else { "" }

        if (-not $NoProxy -and ($null -eq $first_arg -or $first_arg -notmatch $help_re)) {
            Write-Host "Setting opencode with proxy..."
        }

        $opencodeBin = (Get-Command opencode -CommandType Application | Select-Object -First 1).Source
        if ($NoProxy) {
            & $opencodeBin @RemainingArgs
        } else {
            if (Get-Command system_proxy -ErrorAction SilentlyContinue) {
                system_proxy > $null 2>&1
            }
            & $opencodeBin @RemainingArgs
        }
    }
}

# codex with proxy
function codex {
    [CmdletBinding(PositionalBinding = $false)]
    param(
        [Switch]$NoProxy,
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$RemainingArgs
    )

    process {
        $help_re = '^(help|-h|--help|version|-v|-V|--version|completion|login|logout|mcp|plugin|mcp-server|app-server|remote-control|sandbox|debug|apply|a|exec-server|features)$'

        $first_arg = if ($RemainingArgs) { $RemainingArgs[0] } else { "" }

        if (-not $NoProxy -and ($null -eq $first_arg -or $first_arg -notmatch $help_re)) {
            Write-Host "Setting codex with proxy..."
        }

        $codexBin = (Get-Command codex -CommandType Application | Select-Object -First 1).Source
        if ($NoProxy) {
            & $codexBin @RemainingArgs
        } else {
            if (Get-Command system_proxy -ErrorAction SilentlyContinue) {
                system_proxy > $null 2>&1
            }
            & $codexBin @RemainingArgs
        }
    }
}


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

# --- Cygwin 动态加载---
# 不要前置！Cygwin 的 git/ssh 等会遮蔽原生工具（Git for Windows / OpenSSH），
$cygwinCandidatePaths = @('D:\cygwin64\bin', 'C:\cygwin64\bin')
foreach ($binPath in $cygwinCandidatePaths) {
    if (Test-Path -LiteralPath $binPath) {
        if ($env:PATH -notlike "*$binPath*") {
            $env:PATH = "$env:PATH;$binPath"
        }
        break
    }
}
