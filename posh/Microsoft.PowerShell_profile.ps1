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
function pi {
    & (Join-Path $HOME 'dotfiles\posh\start-pi.ps1') @args
    $global:LASTEXITCODE = $LASTEXITCODE
}

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


# Disable Antigravity CLI (agy) auto-update
$env:AGY_CLI_DISABLE_AUTO_UPDATE = 'true'

# agy with proxy & per-conversation model restore on resume
function Get-AgyConversationModel {
    param([string[]]$AgyArgs)

    if (-not $AgyArgs -or $AgyArgs.Count -eq 0) { return $null }
    if ($AgyArgs[0] -match '^(acp|agent|agents|changelog|help|install|mcp|mic-serve|models|plugin|plugins|remote-control|update)$') {
        return $null
    }

    $hasExplicitModel = $false
    $useContinue = $false
    $conversationId = $null
    $valueFlagsRe = '^(-p|--?print|--?prompt|-i|--?prompt-interactive|--?add-dir|--?agent|--?effort|--?input-format|--?json-schema|--?log-file|--?mode|--?output-format|--?print-timeout|--?project)$'

    for ($i = 0; $i -lt $AgyArgs.Count; $i++) {
        $arg = $AgyArgs[$i]
        if ($arg -eq '--') { break }
        if ($arg -match '^(-h|--?help)$') { return $null }

        if ($arg -match '^--?model(=|$)') {
            $hasExplicitModel = $true
            if ($arg -notmatch '=' -and $i + 1 -lt $AgyArgs.Count) { $i++ }
            continue
        }
        if ($arg -match '^--?settings(?:=(.*))?$') {
            $settingsVal = if ($arg -match '=') { $Matches[1] } elseif ($i + 1 -lt $AgyArgs.Count) { $i++; $AgyArgs[$i] } else { '' }
            if (-not [string]::IsNullOrWhiteSpace($settingsVal)) {
                try {
                    $raw = if (Test-Path -LiteralPath $settingsVal) { Get-Content -LiteralPath $settingsVal -Raw -Encoding UTF8 } else { $settingsVal }
                    $obj = $raw | ConvertFrom-Json
                    if ($null -ne $obj -and $obj.PSObject.Properties.Name -contains 'model' -and -not [string]::IsNullOrWhiteSpace([string]$obj.model)) {
                        $hasExplicitModel = $true
                    }
                } catch {}
            }
            continue
        }
        if ($arg -match '^(-c|--?continue)$') {
            $useContinue = $true
            continue
        }
        if ($arg -match '^(-r|--?resume|--?conversation)=(.+)$') {
            $conversationId = $Matches[2]
            continue
        }
        if ($arg -match '^(-r|--?resume|--?conversation)$') {
            if ($i + 1 -lt $AgyArgs.Count -and $AgyArgs[$i + 1] -notlike '-*') {
                $i++
                $conversationId = $AgyArgs[$i]
            }
            continue
        }
        if ($arg -match $valueFlagsRe) {
            if ($i + 1 -lt $AgyArgs.Count) { $i++ }
            continue
        }
    }

    if ($hasExplicitModel) { return $null }

    if (-not $conversationId -and $useContinue) {
        $cachePath = Join-Path $HOME '.gemini\antigravity-cli\cache\last_conversations.json'
        if (Test-Path -LiteralPath $cachePath) {
            $normPath = {
                param([string]$p)
                if ([string]::IsNullOrWhiteSpace($p)) { return '' }
                $t = $p.TrimEnd('\', '/')
                if ($t -match '^[A-Za-z]:$') { return "$t\" }
                return $t
            }
            $target = & $normPath (Get-Location).ProviderPath
            try {
                $map = Get-Content -LiteralPath $cachePath -Raw -Encoding UTF8 | ConvertFrom-Json
                foreach ($prop in $map.PSObject.Properties) {
                    if ((& $normPath $prop.Name) -ieq $target) {
                        $conversationId = [string]$prop.Value
                        break
                    }
                }
            } catch {}
        }
    }

    if ([string]::IsNullOrWhiteSpace($conversationId)) { return $null }

    $transcriptPath = Join-Path $HOME ".gemini\antigravity-cli\brain\$conversationId\.system_generated\logs\transcript.jsonl"
    if (-not (Test-Path -LiteralPath $transcriptPath)) { return $null }

    $pattern = '"type":"PLANNER_RESPONSE"[^\{]{0,120}"model":"([^"]+)"'
    $fs = $null
    try {
        $fs = [System.IO.File]::Open($transcriptPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        $len = $fs.Length
        if ($len -eq 0) { return $null }

        $tailBytes = 524288
        $offset = [Math]::Max([long]0, $len - $tailBytes)
        [void]$fs.Seek($offset, [System.IO.SeekOrigin]::Begin)
        $buf = New-Object byte[] ($len - $offset)
        $read = $fs.Read($buf, 0, $buf.Length)
        $lines = ([System.Text.Encoding]::UTF8.GetString($buf, 0, $read)) -split "`n"
        $startIdx = if ($offset -gt 0) { 1 } else { 0 }
        for ($i = $lines.Length - 1; $i -ge $startIdx; $i--) {
            $line = $lines[$i]
            if ($line.Contains('"type":"PLANNER_RESPONSE"') -and $line -match $pattern) {
                return $Matches[1]
            }
        }

        if ($offset -gt 0) {
            [void]$fs.Seek(0, [System.IO.SeekOrigin]::Begin)
            $reader = New-Object System.IO.StreamReader($fs, [System.Text.Encoding]::UTF8, $true, 65536, $true)
            try {
                $lastModel = $null
                while ($null -ne ($line = $reader.ReadLine())) {
                    if ($line.Contains('"type":"PLANNER_RESPONSE"') -and $line -match $pattern) {
                        $lastModel = $Matches[1]
                    }
                }
                return $lastModel
            } finally {
                $reader.Dispose()
            }
        }
    } catch {
        return $null
    } finally {
        if ($fs) { $fs.Dispose() }
    }
    return $null
}

function agy {
    $noProxy = $false
    $argList = [System.Collections.Generic.List[string]]::new()
    foreach ($a in $args) {
        if ($a -ieq '-NoProxy') {
            $noProxy = $true
        } else {
            $argList.Add([string]$a)
        }
    }

    $agyBin = (Get-Command agy.exe -CommandType Application -ErrorAction Stop).Source
    [string[]]$effectiveArgs = $argList.ToArray()
    $first_arg = if ($effectiveArgs.Length -gt 0) { $effectiveArgs[0] } else { '' }

    $restoredModel = Get-AgyConversationModel -AgyArgs $effectiveArgs
    if ($restoredModel) {
        $isHeadless = $false
        foreach ($item in $effectiveArgs) {
            if ($item -eq '--') { break }
            if ($item -match '^(-p|--?print|--?prompt)(=|$)') {
                $isHeadless = $true
                break
            }
        }
        if ($first_arg -ne 'acp' -and -not $isHeadless) {
            Write-Host "Restoring session model: $restoredModel" -ForegroundColor DarkCyan
        }
        [string[]]$effectiveArgs = @('--model', $restoredModel) + $effectiveArgs
    }

    $oldHttpProxy = $env:HTTP_PROXY
    $oldHttpsProxy = $env:HTTPS_PROXY
    $oldAllProxy = $env:ALL_PROXY
    try {
        if ($noProxy) {
            unset_proxy 6> $null
        } elseif ($first_arg -notmatch '^(help|-h|--help|--version)$') {
            if ($first_arg -ne 'acp') { Write-Host 'Setting agy with proxy...' }
            system_proxy 6> $null
        }
        & $agyBin @effectiveArgs
    } finally {
        $env:HTTP_PROXY = $oldHttpProxy
        $env:HTTPS_PROXY = $oldHttpsProxy
        $env:ALL_PROXY = $oldAllProxy
    }
}


# Shared Node setup; ordinary terminals keep Conda lazy-loaded.
. (Join-Path $HOME 'dotfiles\posh\lib\node-env.ps1')

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
