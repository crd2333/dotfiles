# Antigravity CLI (agy) wrapper with proxy support and per-conversation model restore on resume.

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
