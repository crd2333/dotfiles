# Proxy helpers for PowerShell.
# Ported from zsh/lib/proxy.zsh. Dot-source this file from your profile.

# Bypass proxy for local addresses.
$env:NO_PROXY = "localhost,127.0.0.1,0.0.0.0,::1"

# Enable Node.js to respect the system proxy settings.
$env:NODE_USE_ENV_PROXY = "1"

# Proxy port (hardcoded, unlike the zsh version).
$SYSTEM_PROXY_PORT = 7890

function system_proxy {
    $port = $SYSTEM_PROXY_PORT
    $env:HTTP_PROXY  = "http://127.0.0.1:${port}"
    $env:HTTPS_PROXY = "http://127.0.0.1:${port}"
    $env:ALL_PROXY   = "socks5h://127.0.0.1:${port}"
    Write-Host "System proxy set: http/https -> 127.0.0.1:${port}, socks -> 127.0.0.1:${port}"
}

function unset_proxy {
    Remove-Item Env:HTTP_PROXY  -ErrorAction SilentlyContinue
    Remove-Item Env:HTTPS_PROXY -ErrorAction SilentlyContinue
    Remove-Item Env:ALL_PROXY   -ErrorAction SilentlyContinue
    Write-Host "System proxy environment variables unset"
}

function test_proxy {
    [CmdletBinding()]
    param(
        [Alias('i', 'ip')]
        [switch]$CheckIp,
        [Alias('s', 'stable')]
        [switch]$CheckStable,
        [Alias('h', 'help')]
        [switch]$ShowHelp
    )

    # Configuration
    $targetUrl    = "https://www.google.com"
    $stabilityUrl = "http://speed.cloudflare.com/__down?bytes=5000000"  # 5MB
    $ipCheckUrl   = "http://cip.cc"

    # Colors
    $esc    = [char]27
    $green  = "$esc[0;32m"
    $red    = "$esc[0;31m"
    $yellow = "$esc[0;33m"
    $cyan   = "$esc[0;36m"
    $grey   = "$esc[0;90m"
    $nc     = "$esc[0m"

    # curl discards output to the platform null device
    $nullDev = if ($env:OS -eq 'Windows_NT') { 'NUL' } else { '/dev/null' }

    # Help
    if ($ShowHelp) {
        Write-Host "Usage: test_proxy [options]"
        Write-Host "  (default)   : Basic connectivity and latency check."
        Write-Host "  -i, --ip    : Check external IP address and location."
        Write-Host "  -s, --stable: Run stability (jitter) and throughput tests."
        return 0
    }

    # Pre-check: Environment Variables
    if (-not $env:HTTP_PROXY -or -not $env:HTTPS_PROXY) {
        Write-Host "${yellow}[Warning] Proxy environment variables are NOT set.${nc}"
        return 1
    }

    Write-Host "Proxy: ${cyan}$($env:HTTP_PROXY)${nc}"

    # Step 1: Basic Connectivity & Latency (Always Run)
    Write-Host -NoNewline "Connecting to Google... "

    # -w output format: http_code:time_namelookup:time_connect:time_appconnect:time_total
    $result = & curl.exe -s -o $nullDev `
        -w "%{http_code}:%{time_namelookup}:%{time_connect}:%{time_appconnect}:%{time_total}" `
        --connect-timeout 5 $targetUrl 2>$null
    $curlExitCode = $LASTEXITCODE

    if ($curlExitCode -ne 0) {
        Write-Host "${red}FAILED${nc} (curl error: $curlExitCode)"
        Write-Host "Possible reasons: Proxy down, Firewall, or DNS failure."
        return 1
    }

    $parts     = (($result -join '') -split ':' | ForEach-Object { $_.Trim() })
    $httpCode  = $parts[0]
    $timeDns   = $parts[1]
    $timeTcp   = $parts[2]
    $timeSsl   = $parts[3]
    $timeTotal = $parts[4]

    if ($httpCode -in @('200', '301', '302')) {
        Write-Host "${green}OK${nc} (HTTP $httpCode)"
        Write-Host "${grey}Details: DNS ${timeDns}s | TCP ${timeTcp}s | SSL ${timeSsl}s | Total ${timeTotal}s${nc}"
    } else {
        Write-Host "${red}FAILED${nc} (HTTP Status: $httpCode)"
        return 1
    }

    # Step 2: IP Check (Optional via -i)
    if ($CheckIp) {
        Write-Host "-------------------------------------"
        Write-Host -NoNewline "Checking External IP... "
        $ipInfo = & curl.exe -s --max-time 3 $ipCheckUrl 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "${green}DONE${nc}"
            $ipInfo | Select-Object -First 3 | ForEach-Object { Write-Host "  $_" }
        } else {
            Write-Host "${red}TIMEOUT${nc} (Is the proxy too slow?)"
        }
    }

    # Step 3: Stability & Throughput (Optional via -s)
    if ($CheckStable) {
        Write-Host "-------------------------------------"
        Write-Host "Running ${yellow}Stability Tests${nc}..."

        # 3.1 Jitter Test
        Write-Host "1. Jitter (5 sequential requests):"
        $successCnt = 0
        for ($i = 1; $i -le 5; $i++) {
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            & curl.exe -s -I --connect-timeout 2 $targetUrl *> $null
            $ret = $LASTEXITCODE
            $sw.Stop()
            $duration = $sw.ElapsedMilliseconds

            if ($ret -eq 0) {
                $successCnt++
                $color = if ($duration -lt 500) { $green }
                         elseif ($duration -lt 1000) { $yellow }
                         else { $red }
                Write-Host "   [$i] ${color}${duration}ms${nc}"
            } else {
                Write-Host "   [$i] ${red}Fail${nc}"
            }
        }

        # 3.2 Throughput Test
        Write-Host "2. Throughput (Downloading 5MB sample):"
        & curl.exe -L -o $nullDev --progress-bar `
            -w "   Avg Speed: %{speed_download} bytes/sec`n" `
            --max-time 20 $stabilityUrl
        $dlRet = $LASTEXITCODE

        if ($dlRet -eq 0) {
            Write-Host "   Result: ${green}PASS${nc}"
        } elseif ($dlRet -eq 28) {
            Write-Host "   Result: ${red}TIMEOUT${nc} (Connection unstable for large files)"
        } else {
            Write-Host "   Result: ${red}ERROR${nc} (curl code: $dlRet)"
        }
    }
}

# Remove zombie processes that may be holding the proxy port.
# After executing this, reload the affected application to restart its proxy client.
function clean_proxy {
    Get-NetTCPConnection -LocalPort $SYSTEM_PROXY_PORT -State Listen -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty OwningProcess -Unique |
        ForEach-Object {
            try {
                Stop-Process -Id $_ -Force -ErrorAction Stop
                Write-Host "Killed process $_ holding port $SYSTEM_PROXY_PORT"
            } catch {
                Write-Warning "Failed to kill process $_ on port $SYSTEM_PROXY_PORT"
            }
        }
}
