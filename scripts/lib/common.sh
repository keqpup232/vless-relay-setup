#!/bin/bash
# Common functions for VPN setup scripts

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

check_os() {
    if ! grep -qi "ubuntu" /etc/os-release 2>/dev/null; then
        log_error "This script requires Ubuntu"
        exit 1
    fi
    log_ok "OS: Ubuntu detected"
}

prompt_input() {
    local prompt="$1"
    local var_name="$2"
    local default="${3:-}"
    local input
    if [[ -n "$default" ]]; then
        read -rp "$prompt [$default]: " input
        printf -v "$var_name" '%s' "${input:-$default}"
    else
        read -rp "$prompt: " input
        printf -v "$var_name" '%s' "$input"
    fi
}

prompt_password() {
    local prompt="$1"
    local var_name="$2"
    local input

    while true; do
        read -srp "$prompt: " input
        echo
        if [[ -z "$input" ]]; then
            log_warn "Password cannot be empty"
            continue
        fi
        if [[ "$input" =~ $'\e' ]] || [[ "$input" =~ $'\x1b' ]] || [[ "$input" =~ [[:cntrl:]] ]]; then
            log_warn "Password contains control characters - try pasting with Shift+Insert instead of Ctrl+V"
            continue
        fi
        if [[ "$input" =~ ^[[:space:]]|[[:space:]]$ ]]; then
            log_warn "Password contains leading or trailing spaces"
            continue
        fi
        if [[ ${#input} -lt 6 ]]; then
            log_warn "Password should be at least 6 characters long"
            continue
        fi
        break
    done
    printf -v "$var_name" "%s" "$input"
}

validate_ascii() {
    local value="$1"
    local name="$2"
    if [[ ! "$value" =~ ^[a-zA-Z0-9_.-]+$ ]]; then
        log_error "$name contains invalid characters (use English letters, digits, _ . -)"
        return 1
    fi
}

validate_ip() {
    local ip="$1"
    [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

validate_uuid() {
    local uuid="$1"
    [[ "$uuid" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]
}

validate_not_empty() {
    local value="$1"
    local name="$2"
    if [[ -z "$value" ]]; then
        log_error "$name cannot be empty"
        return 1
    fi
}

generate_random_port() {
    shuf -i 10000-60000 -n 1
}

generate_random_path() {
    openssl rand -hex 8
}

install_dependencies() {
    log_info "Installing dependencies..."
    apt-get update -qq
    apt-get install -y -qq curl wget unzip jq openssl cron socat git sqlite3 > /dev/null 2>&1
    log_ok "Dependencies installed"
}

update_system() {
    log_info "Updating system..."
    apt-get update -qq && apt-get upgrade -y -qq > /dev/null 2>&1
    log_ok "System updated"
}

validate_domain() {
    local domain="$1"
    if [[ "$domain" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]] && \
       [[ ! "$domain" =~ -- ]] && \
       [[ ! "$domain" =~ ^- ]] && \
       [[ ! "$domain" =~ -$ ]]; then
        return 0
    else
        return 1
    fi
}

validate_choice() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    shift 3
    local valid_options=("$@")

    local input
    while true; do
        read -rp "$prompt [$default]: " input
        input="${input:-$default}"

        # Проверяем, есть ли ввод в списке допустимых опций
        for opt in "${valid_options[@]}"; do
            if [[ "$input" == "$opt" ]]; then
                printf -v "$var_name" '%s' "$input"
                return 0
            fi
        done

        # Если не нашли
        log_warn "Invalid option. Please enter one of: ${valid_options[*]}"
    done
}