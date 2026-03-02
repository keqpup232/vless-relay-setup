#!/bin/bash
# Post-setup verification

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

verify_service_running() {
    local service="$1"
    local label="$2"
    if systemctl is-active --quiet "$service"; then
        log_ok "$label is running"
        return 0
    else
        log_error "$label is NOT running"
        log_error "  Check: journalctl -u $service --no-pager -n 20"
        return 1
    fi
}

verify_port_listening() {
    local port="$1"
    local label="$2"
    if ss -tlnp | grep -q ":${port} "; then
        log_ok "$label is listening on port $port"
        return 0
    else
        log_error "$label is NOT listening on port $port"
        return 1
    fi
}

verify_exit_server() {
    local panel_port="$1"

    log_info "=== Verification ==="
    local ok=true

    verify_service_running xray "XRAY" || ok=false
    verify_service_running x-ui "3X-UI" || ok=false
    verify_port_listening 443 "XRAY" || ok=false
    verify_port_listening "$panel_port" "3X-UI Panel" || ok=false

    if [[ "$ok" == true ]]; then
        log_ok "Exit server verification PASSED"
    else
        log_error "Exit server verification FAILED — check errors above"
    fi
}

verify_relay_server() {
    local panel_port="$1"
    local sub_port="${2:-}"
    local exit_ip="$3"
    local exit_port="$4"

    log_info "=== Verification ==="
    local ok=true

    verify_service_running x-ui "3X-UI" || ok=false
    verify_port_listening 443 "XRAY (via 3X-UI)" || ok=false
    verify_port_listening "$panel_port" "3X-UI Panel" || ok=false

    if [[ -n "$sub_port" ]]; then
        verify_port_listening "$sub_port" "Subscription" || ok=false
    fi

    # Test relay → exit connectivity
    log_info "Testing connection to exit server (${exit_ip}:${exit_port})..."
    if timeout 5 bash -c "echo >/dev/tcp/${exit_ip}/${exit_port}" 2>/dev/null; then
        log_ok "Exit server is reachable at ${exit_ip}:${exit_port}"
    else
        log_error "Cannot reach exit server at ${exit_ip}:${exit_port}"
        log_error "  Check: exit server firewall and XRAY service"
        ok=false
    fi

    if [[ "$ok" == true ]]; then
        log_ok "Relay server verification PASSED"
    else
        log_error "Relay server verification FAILED — check errors above"
    fi
}
