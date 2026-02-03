# Proxy helpers for zsh.
# Keep this file POSIX-ish, but it is sourced by zsh.

# Bypass proxy for local addresses.
export no_proxy="localhost,127.0.0.1,::1"

# Default ports (override in .zshrc before sourcing if needed).
: "${SYSTEM_PROXY_HTTP_PORT:=20171}"
: "${SYSTEM_PROXY_SOCKS_PORT:=20170}"

system_proxy() {
    export http_proxy="http://127.0.0.1:${SYSTEM_PROXY_HTTP_PORT}"
    export https_proxy="http://127.0.0.1:${SYSTEM_PROXY_HTTP_PORT}"
    export all_proxy="socks5://127.0.0.1:${SYSTEM_PROXY_SOCKS_PORT}"
    echo "System proxy set: http/https -> 127.0.0.1:${SYSTEM_PROXY_HTTP_PORT}, socks -> 127.0.0.1:${SYSTEM_PROXY_SOCKS_PORT}"
}

unset_proxy() {
    unset http_proxy https_proxy all_proxy
    echo "System proxy environment variables unset"
}

test_proxy() {
    # Configuration
    local TARGET_URL="https://www.google.com"
    local STABILITY_URL="http://speed.cloudflare.com/__down?bytes=5000000" # 5MB
    local IP_CHECK_URL="http://cip.cc"

    # Colors
    local GREEN='\033[0;32m'
    local RED='\033[0;31m'
    local YELLOW='\033[0;33m'
    local CYAN='\033[0;36m'
    local GREY='\033[0;90m'
    local NC='\033[0m'

    # Argument Parsing
    local check_ip=false
    local check_stable=false

    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -i|--ip) check_ip=true ;;
            -s|--stable) check_stable=true ;;
            -h|--help)
                echo "Usage: test_proxy [options]"
                echo "  (default)   : Basic connectivity and latency check."
                echo "  -i, --ip    : Check external IP address and location."
                echo "  -s, --stable: Run stability (jitter) and throughput tests."
                return 0
                ;;
            *) echo -e "${RED}Unknown parameter: $1${NC}"; return 1 ;;
        esac
        shift
    done

    # Pre-check: Environment Variables
    if [[ -z "$http_proxy" ]] || [[ -z "$https_proxy" ]]; then
        echo -e "${YELLOW}[Warning] Proxy environment variables are NOT set.${NC}"
        return 1
    fi

    echo -e "Proxy: ${CYAN}$http_proxy${NC}"

    # Step 1: Basic Connectivity & Latency (Always Run)
    echo -ne "Connecting to Google... "

    # -w output format: http_code:time_namelookup:time_connect:time_appconnect:time_total
    local result
    result=$(curl -s -o /dev/null -w "%{http_code}:%{time_namelookup}:%{time_connect}:%{time_appconnect}:%{time_total}" --connect-timeout 5 "$TARGET_URL")
    local curl_exit_code=$?

    if [ $curl_exit_code -ne 0 ]; then
        echo -e "${RED}FAILED${NC} (curl error: $curl_exit_code)"
        echo "Possible reasons: Proxy down, Firewall, or DNS failure."
        return 1
    fi

    local http_code time_dns time_tcp time_ssl time_total
    http_code=$(echo "$result" | cut -d':' -f1)
    time_dns=$(echo "$result" | cut -d':' -f2)
    time_tcp=$(echo "$result" | cut -d':' -f3)
    time_ssl=$(echo "$result" | cut -d':' -f4)
    time_total=$(echo "$result" | cut -d':' -f5)

    if [[ "$http_code" == "200" ]] || [[ "$http_code" == "301" ]] || [[ "$http_code" == "302" ]]; then
        echo -e "${GREEN}OK${NC} (HTTP $http_code)"
        echo -e "${GREY}Details: DNS ${time_dns}s | TCP ${time_tcp}s | SSL ${time_ssl}s | Total ${time_total}s${NC}"
    else
        echo -e "${RED}FAILED${NC} (HTTP Status: $http_code)"
        return 1
    fi

    # Step 2: IP Check (Optional via -i)
    if [ "$check_ip" = true ]; then
        echo "-------------------------------------"
        echo -ne "Checking External IP... "
        local ip_info
        ip_info=$(curl -s --max-time 3 "$IP_CHECK_URL")
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}DONE${NC}"
            echo "$ip_info" | head -n 3 | sed 's/^/  /g'
        else
            echo -e "${RED}TIMEOUT${NC} (Is the proxy too slow?)"
        fi
    fi

    # Step 3: Stability & Throughput (Optional via -s)
    if [ "$check_stable" = true ]; then
        echo "-------------------------------------"
        echo -e "Running ${YELLOW}Stability Tests${NC}..."

        # 3.1 Jitter Test
        echo -e "1. Jitter (5 sequential requests):"
        local success_cnt=0
        local i
        for i in {1..5}; do
            local start_ts end_ts duration ret color
            start_ts=$(date +%s%N)
            curl -s -I --connect-timeout 2 "$TARGET_URL" > /dev/null
            ret=$?
            end_ts=$(date +%s%N)
            duration=$(( (end_ts - start_ts) / 1000000 )) # ms

            if [ $ret -eq 0 ]; then
                ((success_cnt++))
                if [ $duration -lt 500 ]; then color=$GREEN;
                elif [ $duration -lt 1000 ]; then color=$YELLOW;
                else color=$RED; fi
                echo -e "   [$i] ${color}${duration}ms${NC}"
            else
                echo -e "   [$i] ${RED}Fail${NC}"
            fi
        done

        # 3.2 Throughput Test
        echo -e "2. Throughput (Downloading 5MB sample):"
        curl -L -o /dev/null --progress-bar -w "   Avg Speed: %{speed_download} bytes/sec\n" --max-time 20 "$STABILITY_URL"
        local dl_ret=$?

        if [ $dl_ret -eq 0 ]; then
            echo -e "   Result: ${GREEN}PASS${NC}"
        elif [ $dl_ret -eq 28 ]; then
            echo -e "   Result: ${RED}TIMEOUT${NC} (Connection unstable for large files)"
        else
            echo -e "   Result: ${RED}ERROR${NC} (curl code: $dl_ret)"
        fi
    fi
}
