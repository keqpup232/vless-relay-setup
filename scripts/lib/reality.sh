#!/bin/bash
# Reality dest site discovery and key generation

source "$(dirname "$0")/common.sh"

generate_reality_keypair() {
    log_info "Generating x25519 key pair for Reality..."

    local keys
    keys=$(xray x25519)

    export REALITY_PRIVATE_KEY
    REALITY_PRIVATE_KEY=$(echo "$keys" | grep "Private" | awk '{print $3}')
    export REALITY_PUBLIC_KEY
    REALITY_PUBLIC_KEY=$(echo "$keys" | grep "Public" | awk '{print $3}')

    log_ok "Reality keys generated"
    log_info "  Private key: $REALITY_PRIVATE_KEY"
    log_info "  Public key:  $REALITY_PUBLIC_KEY"
}

generate_short_id() {
    export REALITY_SHORT_ID
    REALITY_SHORT_ID=$(openssl rand -hex 4)
    log_ok "Short ID generated: $REALITY_SHORT_ID"
}

check_site_tls13() {
    local domain="$1"
    local result
    result=$(echo | timeout 5 openssl s_client -connect "$domain:443" \
        -tls1_3 -brief 2>&1 | grep -c "TLSv1.3" || true)
    [[ "$result" -ge 1 ]]
}

check_site_h2() {
    local domain="$1"
    local result
    result=$(curl -sI --max-time 5 "https://$domain" \
        -o /dev/null -w '%{http_version}' 2>/dev/null || echo "0")
    [[ "$result" == "2" ]]
}

scan_nearby_sites() {
    log_info "Scanning for suitable Reality dest sites..."

    local server_ip
    server_ip=$(curl -s4 ifconfig.me)
    local base_ip
    base_ip=$(echo "$server_ip" | cut -d. -f1-3)

    local candidates=()

    # Scan nearby IPs for sites with TLS 1.3
    for i in $(shuf -i 1-254 -n 30); do
        local ip="${base_ip}.${i}"
        [[ "$ip" == "$server_ip" ]] && continue

        local domain
        domain=$(timeout 3 dig +short -x "$ip" 2>/dev/null | sed 's/\.$//' | head -1)
        [[ -z "$domain" ]] && continue

        if check_site_tls13 "$domain" 2>/dev/null; then
            candidates+=("$domain")
            log_info "  Found: $domain ($ip) — TLS 1.3 OK"
            [[ ${#candidates[@]} -ge 5 ]] && break
        fi
    done

    # Fallback well-known sites
    local fallbacks=("www.microsoft.com" "www.apple.com" "dl.google.com" "www.samsung.com" "www.logitech.com")

    if [[ ${#candidates[@]} -eq 0 ]]; then
        log_warn "No nearby sites found. Using known TLS 1.3 sites."
        candidates=("${fallbacks[@]}")
    fi

    echo ""
    log_info "Suitable sites for Reality dest:"
    for i in "${!candidates[@]}"; do
        echo "  $((i+1)). ${candidates[$i]}"
    done

    local choice
    prompt_input "Select site number (or enter custom domain)" choice "1"

    if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -le "${#candidates[@]}" ]]; then
        export REALITY_DEST
        REALITY_DEST="${candidates[$((choice-1))]}"
    else
        export REALITY_DEST
        REALITY_DEST="$choice"
    fi

    export REALITY_SERVER_NAME="$REALITY_DEST"
    log_ok "Reality dest: $REALITY_DEST"
}

setup_reality() {
    scan_nearby_sites
    generate_reality_keypair
    generate_short_id
}
