#!/bin/bash
# 3X-UI panel installation and configuration

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

XUI_BIN="${XUI_MAIN_FOLDER:-/usr/local/x-ui}/x-ui"
XUI_DB="/etc/x-ui/x-ui.db"

install_3xui() {
    log_info "Installing 3X-UI panel..."

    bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh) <<< "y"

    if command -v x-ui &> /dev/null; then
        log_ok "3X-UI installed"
    else
        log_error "3X-UI installation failed"
        exit 1
    fi
}

# Set a key-value pair in x-ui settings database
xui_db_set() {
    local key="$1"
    local value="$2"

    local exists
    exists=$(sqlite3 "$XUI_DB" "SELECT COUNT(*) FROM settings WHERE key='$key';")

    if [[ "$exists" -gt 0 ]]; then
        sqlite3 "$XUI_DB" "UPDATE settings SET value='$value' WHERE key='$key';"
    else
        sqlite3 "$XUI_DB" "INSERT INTO settings (key, value) VALUES ('$key', '$value');"
    fi
}

configure_3xui() {
    local panel_port="$1"
    local panel_path="$2"
    local admin_user="$3"
    local admin_pass="$4"

    log_info "Configuring 3X-UI panel..."

    # Set panel port
    "$XUI_BIN" setting -port "$panel_port"

    # Set panel URL path
    "$XUI_BIN" setting -webBasePath "/$panel_path/"

    # Set admin credentials
    "$XUI_BIN" setting -username "$admin_user" -password "$admin_pass"

    # TLS is already configured by the 3X-UI installer (acme.sh)

    # Restart to apply
    x-ui restart

    log_ok "3X-UI configured:"
    log_info "  URL: https://<server-ip>:${panel_port}/${panel_path}/"
    log_info "  User: $admin_user"
}

configure_3xui_subscription() {
    local domain="$1"
    local sub_port="$2"
    local sub_path="$3"

    log_info "Configuring subscription service..."

    # Subscription settings are not available via CLI flags,
    # configure directly in the x-ui SQLite database
    xui_db_set "subEnable" "true"
    xui_db_set "subPort" "$sub_port"
    xui_db_set "subPath" "/$sub_path/"
    xui_db_set "subDomain" "$domain"

    x-ui restart

    log_ok "Subscription configured:"
    log_info "  URL: https://${domain}:${sub_port}/${sub_path}/"
}
