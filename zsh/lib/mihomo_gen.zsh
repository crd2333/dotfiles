#!/bin/zsh
# This script generates config.yaml for Mihomo core.

local conf_file="$1"
rm -f "$conf_file"

# Part 1: Basic Configuration
{
  echo "mixed-port: ${SYSTEM_PROXY_PORT_BACKUP:-20171}"  # Mixed HTTP/SOCKS5 port, from environment variable
  echo "geodata-mode: true"                              # Use geoip.dat (true) or mmdb (false)
  echo "tcp-concurrent: true"                            # Enable TCP concurrency for better performance
  echo "unified-delay: true"                             # Unified delay display for all nodes
  echo "allow-lan: false"                                # Allow connections from local network devices
  echo "bind-address: '*'"                               # Listen on all available IP addresses
  echo "find-process-mode: strict"                       # Process matching: strict, off, or always
  echo "ipv6: false"                                     # Disable IPv6 support
  echo "mode: rule"                                      # Running mode: rule, global, or direct
  echo "log-level: info"                                 # Log verbosity: debug, info, warning, error, silent
  echo ""
} >> "$conf_file"

# Part 2: External Control
{
  echo "external-controller: '127.0.0.1:2017'" # API address for external dashboards
  echo "external-ui: ./ui"                     # Path to the dashboard UI files
  echo "secret: '${MIHOMO_SECRET}'"            # Dashboard access password
  echo ""
} >> "$conf_file"

# Part 3: Performance Tuning
{
  echo "tcp-concurrent-users: 64"            # Concurrent TCP connections (Suggested: 16-128)
  echo "keep-alive-interval: 15"             # Keep-alive heartbeat interval in seconds
  echo "inbound-tfo: true"                   # Enable TCP Fast Open for inbound connections
  echo "outbound-tfo: true"                  # Enable TCP Fast Open for outbound connections
  echo "connection-pool-size: 256"           # Connection pool capacity (Suggested: 128-512)
  echo "idle-timeout: 60"                    # Connection idle timeout in seconds
  # echo "interface-name: en0"               # Optional: Bind to specific network interface
  echo ""
} >> "$conf_file"

# Part 4: TLS Configuration
{
  echo "tls:"
  echo "  enable: true"                      # Enable TLS support
  echo "  skip-cert-verify: false"           # Verify certificates for security
  echo "  alpn:"                             # Application-Layer Protocol Negotiation
  echo "    - h2"                            # HTTP/2
  echo "    - http/1.1"                      # HTTP/1.1
  echo "  min-version: '1.2'"                # Minimum supported TLS version
  echo "  max-version: '1.3'"                # Maximum supported TLS version
  echo "  cipher-suites:"                    # Cipher suite priority
  echo "    - TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256"
  echo "    - TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256"
  echo "    - TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305"
  echo "    - TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305"
} >> "$conf_file"

# Part 5: Proxy Providers
echo "proxy-providers:" >> "$conf_file"
for sub in "${AIRPORT_SUBS[@]}"; do
    local name="${sub%%|*}"
    local url="${sub#*|}"
    [ -z "$name" ] && continue  # 🛡️ Safeguard: Skip empty array elements

    {
      echo "  ${name}-Sub:"
      echo "    type: http"
      echo "    url: \"${url}\""
      echo "    path: ./proxies/${name}.yaml"
      echo "    interval: 86400"
      echo "    health-check:"
      echo "      enable: true"
      echo "      url: http://www.gstatic.com/generate_204"
      echo "      interval: 300"
      echo "      lazy: true"
    } >> "$conf_file"
done
echo "" >> "$conf_file"

# Part 6: Proxy Groups
echo "proxy-groups:" >> "$conf_file"

# A. Top-level group
{
  echo "  - name: Proxy"
  echo "    type: select"
  echo "    proxies:"
} >> "$conf_file"
for sub in "${AIRPORT_SUBS[@]}"; do
    local name="${sub%%|*}"
    [ -z "$name" ] && continue
    echo "      - ${name}" >> "$conf_file"
done

# B. Manual selection groups
for sub in "${AIRPORT_SUBS[@]}"; do
    local name="${sub%%|*}"
    [ -z "$name" ] && continue
    {
      echo "  - name: ${name}"
      echo "    type: select"
      echo "    proxies:"
      echo "      - ${name}-Auto"
      echo "    use:"
      echo "      - ${name}-Sub"
    } >> "$conf_file"
done

# C. Auto-test groups
for sub in "${AIRPORT_SUBS[@]}"; do
    local name="${sub%%|*}"
    [ -z "$name" ] && continue
    {
      echo "  - name: ${name}-Auto"
      echo "    type: url-test"
      echo "    url: 'http://www.gstatic.com/generate_204'"
      echo "    interval: 300"
      echo "    lazy: true"
      echo "    use:"
      echo "      - ${name}-Sub"
    } >> "$conf_file"
done
echo "" >> "$conf_file"

# Part 7: Routing Rules
{
  echo "rules:"
  echo "  - MATCH,Proxy"

  # local rules
  echo "  - DOMAIN-SUFFIX,local,DIRECT"
  echo "  - DOMAIN-SUFFIX,localhost,DIRECT"
  echo "  - IP-CIDR,127.0.0.0/8,DIRECT"
  echo "  - IP-CIDR,172.16.0.0/12,DIRECT"
  echo "  - IP-CIDR,192.168.0.0/16,DIRECT"
  echo "  - IP-CIDR,10.0.0.0/8,DIRECT"
  echo "  - IP-CIDR,17.0.0.0/8,DIRECT"
  echo "  - IP-CIDR,100.64.0.0/10,DIRECT"
  echo "  - IP-CIDR,224.0.0.0/4,DIRECT"
  echo "  - IP-CIDR6,fe80::/10,DIRECT"

  # custom process-based rules
  echo "  - PROCESS-NAME,clash,DIRECT"
  echo "  - PROCESS-NAME,v2ray,DIRECT"
  echo "  - PROCESS-NAME,xray,DIRECT"
  echo "  - PROCESS-NAME,naive,DIRECT"
  echo "  - PROCESS-NAME,trojan,DIRECT"
  echo "  - PROCESS-NAME,trojan-go,DIRECT"
  echo "  - PROCESS-NAME,ss-local,DIRECT"
  echo "  - PROCESS-NAME,privoxy,DIRECT"
  echo "  - PROCESS-NAME,leaf,DIRECT"
  echo "  - PROCESS-NAME,Thunder,DIRECT"
  echo "  - PROCESS-NAME,DownloadService,DIRECT"
  echo "  - PROCESS-NAME,qBittorrent,DIRECT"
  echo "  - PROCESS-NAME,Transmission,DIRECT"
  echo "  - PROCESS-NAME,fdm,DIRECT"
  echo "  - PROCESS-NAME,aria2c,DIRECT"
  echo "  - PROCESS-NAME,Folx,DIRECT"
  echo "  - PROCESS-NAME,NetTransport,DIRECT"
  echo "  - PROCESS-NAME,uTorrent,DIRECT"
  echo "  - PROCESS-NAME,WebTorrent,DIRECT"

  # custom domain-based rules
  echo "  - DOMAIN-SUFFIX,apple.com,DIRECT"
  echo "  - DOMAIN-SUFFIX,icloud.com,DIRECT"
} >> "$conf_file"
