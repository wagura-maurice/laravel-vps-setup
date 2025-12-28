#!/bin/bash
set -euo pipefail

# Load core configuration and utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CORE_DIR="${SCRIPT_DIR}/core"
source "${CORE_DIR}/env-loader.sh" 2>/dev/null || {
    echo "Error: Failed to load ${CORE_DIR}/env-loader.sh" >&2
    exit 1
}

# Initialize environment and logging
load_environment
init_logging

log_section "Certbot Configuration for Laravel"


# Function to configure Certbot for Laravel
configure_certbot_for_laravel() {
    # Ensure environment is loaded
    load_environment
    
    local domain_name="${DOMAIN_NAME:-localhost}"
    local email="${LETSENCRYPT_EMAIL:-admin@${domain_name}}"
    
    log_info "Configuring Certbot for Laravel with domain: ${domain_name}..."
    
    # Create a configuration file for Certbot
    cat > /etc/letsencrypt/cli.ini <<EOL
# Certbot configuration for Laravel
authenticator = nginx
rsa-key-size = 4096
email = ${email}
domains = ${domain_name}
agree-tos = True
EOL

    # Set proper permissions
    chmod 600 /etc/letsencrypt/cli.ini
    
    log_success "Certbot configuration created for Laravel"
    return 0
}

# Function to set up automatic certificate renewal
setup_automatic_renewal() {
    log_info "Setting up automatic certificate renewal..."
    
    # Create a systemd timer for certbot renewal
    cat > /etc/systemd/system/certbot-renew.timer <<EOL
[Unit]
Description=Certbot renewal timer
Requires=certbot-renew.service

[Timer]
OnCalendar=daily
RandomizedDelaySec=12h
Persistent=true

[Install]
WantedBy=timers.target
EOL

    # Create a systemd service for certbot renewal
    cat > /etc/systemd/system/certbot-renew.service <<EOL
[Unit]
Description=Certbot renewal service
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/bin/certbot renew --quiet --deploy-hook "systemctl reload nginx"
EOL

    # Enable and start the timer
    systemctl daemon-reload
    systemctl enable --now certbot-renew.timer
    
    log_success "Automatic certificate renewal configured"
    return 0
}

# Function to test SSL certificate configuration
test_ssl_configuration() {
    log_info "Testing SSL certificate configuration..."
    
    # Check if SSL certificate exists for the domain
    if [ -f "/etc/letsencrypt/live/${DOMAIN_NAME}/fullchain.pem" ]; then
        log_info "SSL certificate found for ${DOMAIN_NAME}"
        
        # Test renewal
        if certbot renew --dry-run; then
            log_success "SSL certificate renewal test successful"
            return 0
        else
            log_warning "SSL certificate renewal test failed"
            return 1
        fi
    else
        log_info "SSL certificate not yet installed for ${DOMAIN_NAME}, configuration will be used when obtaining certificate"
        return 0
    fi
}

# Main configuration function
configure_certbot_main() {
    log_info "Starting Certbot configuration for Laravel..."
    
    local success=true
    
    # Configure Certbot
    if ! configure_certbot_for_laravel; then
        log_error "Failed to configure Certbot for Laravel"
        success=false
    fi
    
    # Set up automatic renewal
    if ! setup_automatic_renewal; then
        log_error "Failed to set up automatic renewal"
        success=false
    fi
    
    # Test SSL configuration
    if ! test_ssl_configuration; then
        log_warning "SSL configuration test had issues"
    fi
    
    if [ "${success}" = true ]; then
        log_success "Certbot configuration for Laravel completed successfully!"
        log_info "To obtain SSL certificate, run: sudo certbot --nginx -d ${DOMAIN_NAME}"
        log_info "Automatic renewal is configured to run daily with randomized delay"
        return 0
    else
        log_error "Certbot configuration completed with errors"
        return 1
    fi
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi

    configure_certbot_main
    exit $?
fi