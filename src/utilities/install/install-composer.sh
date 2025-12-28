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

log_section "Composer Installation"

# Function to install Composer
install_composer() {
    log_info "Installing Composer..."

    # Download and install Composer
    cd /tmp
    curl -sS https://getcomposer.org/installer | php

    # Install globally for root
    if ! mv composer.phar /usr/local/bin/composer; then
        log_error "Failed to move composer.phar to /usr/local/bin/composer"
        return 1
    fi

    # Make it executable
    if ! chmod +x /usr/local/bin/composer; then
        log_error "Failed to make composer executable"
        return 1
    fi

    # Install for deployer user
    sudo -u deployer -H bash -c "
        cd /tmp
        curl -sS https://getcomposer.org/installer | php
        mkdir -p /home/deployer/.config/composer
        mv composer.phar /usr/local/bin/composer
        chmod +x /usr/local/bin/composer
    "

    # Add to PATH for deployer user and ensure proper configuration
    sudo -u deployer -H bash -c "mkdir -p ~/.config/composer"
    echo 'export PATH="$PATH:/usr/local/bin"' >> /home/deployer/.bashrc
    
    # Ensure the deployer user can access Composer globally
    sudo -u deployer -H bash -c "
        composer global dump-autoload
        mkdir -p /home/deployer/.composer
        chmod -R 755 /home/deployer/.composer
    "

    log_success "Composer installed successfully for both root and deployer users"
    return 0
}

# Function to verify installation
verify_installation() {
    log_info "Verifying Composer installation..."

    # Check if Composer is available for root
    if ! command -v composer &> /dev/null; then
        log_error "Composer installation verification failed for root user"
        return 1
    fi

    # Check version
    local composer_version
    composer_version=$(composer --version 2>&1 | head -n1)

    if [[ -z "${composer_version}" ]]; then
        log_error "Could not determine Composer version"
        return 1
    fi

    log_success "Composer ${composer_version} is installed and working for root user"

    # Check if Composer is available for deployer user
    if ! sudo -u deployer -H composer --version &> /dev/null; then
        log_error "Composer installation verification failed for deployer user"
        return 1
    fi

    local deployer_composer_version
    deployer_composer_version=$(sudo -u deployer -H composer --version 2>&1 | head -n1)

    log_success "Composer ${deployer_composer_version} is installed and working for deployer user"
    return 0
}

# Main installation function
install_composer_main() {
    log_info "Starting Composer installation..."

    if ! install_composer; then
        log_error "Failed to install Composer"
        return 1
    fi

    if ! verify_installation; then
        log_warning "Composer installation verification had issues"
        return 1
    fi

    log_success "Composer installation completed successfully"
    log_info "Composer is now available for both root and deployer users"
    return 0
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi

    install_composer_main
    exit $?
fi