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
    if [[ -n "$default" ]]; then
        read -rp "$prompt [$default]: " input
        eval "$var_name='${input:-$default}'"
    else
        read -rp "$prompt: " input
        eval "$var_name='$input'"
    fi
}

prompt_password() {
    local prompt="$1"
    local var_name="$2"
    read -srp "$prompt: " input
    echo
    eval "$var_name='$input'"
}

generate_random_port() {
    shuf -i 10000-60000 -n 1
}

generate_random_path() {
    head -c 16 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 16
}

install_dependencies() {
    log_info "Installing dependencies..."
    apt-get update -qq
    apt-get install -y -qq curl wget unzip jq openssl cron socat git > /dev/null 2>&1
    log_ok "Dependencies installed"
}

update_system() {
    log_info "Updating system..."
    apt-get update -qq && apt-get upgrade -y -qq > /dev/null 2>&1
    log_ok "System updated"
}
