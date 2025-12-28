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

log_section "System Configuration for Laravel"


# Function to set system timezone
set_timezone() {
    log_info "Setting system timezone to ${TIMEZONE}..."
    
    # Set the system timezone
    if ! timedatectl set-timezone "${TIMEZONE}"; then
        log_error "Failed to set system timezone"
        return 1
    fi
    
    log_success "System timezone set to ${TIMEZONE}"
    return 0
}

# Function to configure system locale
configure_locale() {
    log_info "Configuring system locale..."
    
    # Set default locale
    echo "LC_ALL=en_US.UTF-8" >> /etc/environment
    echo "LANG=en_US.UTF-8" >> /etc/environment
    echo "LANGUAGE=en_US.UTF-8" >> /etc/environment
    
    # Generate locale if not exists
    if ! locale-gen en_US.UTF-8; then
        log_warning "Failed to generate locale"
    fi
    
    # Update locale settings
    update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
    
    log_success "System locale configured"
    return 0
}

# Function to configure fail2ban
configure_fail2ban() {
    log_info "Configuring fail2ban..."
    
    # Create basic fail2ban configuration
    cat > /etc/fail2ban/jail.local <<EOL
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
ignoreip = 127.0.0.1/8

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3

[nginx-http-auth]
enabled = true
port = http,https
filter = nginx-http-auth
logpath = /var/log/nginx/*error.log
maxretry = 3

[nginx-botsearch]
enabled = true
port = http,https
filter = nginx-botsearch
logpath = /var/log/nginx/*access.log
maxretry = 10
EOL

    # Restart fail2ban to apply changes
    systemctl restart fail2ban
    systemctl enable fail2ban
    
    log_success "fail2ban configured"
    return 0
}

# Function to optimize system settings for Laravel
optimize_system() {
    log_info "Optimizing system settings for Laravel..."
    
    # Create system optimization configuration
    cat > /etc/sysctl.d/99-laravel-optimization.conf <<EOL
# File limits
fs.file-max = 100000

# Network optimizations
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_sack = 1

# Memory settings
vm.swappiness = 10
vm.vfs_cache_pressure = 50
EOL

    # Apply the system settings
    sysctl -p /etc/sysctl.d/99-laravel-optimization.conf
    
    log_success "System optimized for Laravel"
    return 0
}

# Function to set up log rotation
setup_log_rotation() {
    log_info "Setting up log rotation..."
    
    # Create logrotate configuration for Laravel
    cat > /etc/logrotate.d/laravel <<EOL
/var/www/html/default_laravel_project/storage/logs/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 644 deployer deployer
    postrotate
        systemctl reload php8.4-fpm > /dev/null 2>&1 || true
    endscript
}
EOL

    log_success "Log rotation configured for Laravel"
    return 0
}

# Main configuration function
configure_system_main() {
    log_info "Starting system configuration for Laravel..."
    
    # Load environment variables first
    load_environment
    
    local success=true
    
    # Set system timezone
    if ! set_timezone; then
        log_error "Failed to set system timezone"
        success=false
    fi
    
    # Configure system locale
    if ! configure_locale; then
        log_error "Failed to configure system locale"
        success=false
    fi
    
    # Configure fail2ban
    if ! configure_fail2ban; then
        log_error "Failed to configure fail2ban"
        success=false
    fi
    
    # Optimize system settings
    if ! optimize_system; then
        log_error "Failed to optimize system settings"
        success=false
    fi
    
    # Set up log rotation
    if ! setup_log_rotation; then
        log_error "Failed to set up log rotation"
        success=false
    fi
    
    if [ "${success}" = true ]; then
        log_success "System configuration for Laravel completed successfully!"
        return 0
    else
        log_error "System configuration completed with errors"
        return 1
    fi
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi

    configure_system_main
    exit $?
fi