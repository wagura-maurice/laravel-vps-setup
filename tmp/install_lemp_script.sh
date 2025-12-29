#!/bin/bash

# Default to interactive mode
INTERACTIVE=true
UBUNTU_VERSION="22.04"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -y|--non-interactive)
            INTERACTIVE=false
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Check Ubuntu version
check_ubuntu_version() {
    if ! command -v lsb_release > /dev/null; then
        sudo apt-get update && sudo apt-get install -y lsb-release
    fi
    
    OS_VERSION=$(lsb_release -rs)
    if [ "$OS_VERSION" != "$UBUNTU_VERSION" ]; then
        log "Warning: This script is optimized for Ubuntu $UBUNTU_VERSION, but you're using Ubuntu $OS_VERSION"
        read -p "Continue anyway? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "Installation aborted by user."
            exit 1
        fi
    fi
}

# Install required dependencies
install_dependencies() {
    log "Installing required dependencies..."
    export DEBIAN_FRONTEND=noninteractive
    sudo apt-get update
    sudo apt-get install -y --no-install-recommends \
        curl \
        wget \
        git \
        unzip \
        software-properties-common \
        apt-transport-https \
        ca-certificates \
        gnupg-agent
}

# Main installation function
run_installation() {
    log "Downloading LEMP installation script for Ubuntu $UBUNTU_VERSION..."
    curl -s -o lemp_install.sh https://raw.githubusercontent.com/wagura-maurice/laravel-vps-setup/refs/heads/main/tmp/LEMP-php8.4.sh
    chmod +x lemp_install.sh

    if [ "$INTERACTIVE" = true ]; then
        log "Starting interactive installation..."
        sudo -E ./lemp_install.sh
    else
        log "Starting non-interactive installation..."
        # Set non-interactive frontend for apt
        echo 'debconf debconf/frontend select Noninteractive' | sudo debconf-set-selections
        # Run installation with non-interactive frontend
        sudo -E DEBIAN_FRONTEND=noninteractive ./lemp_install.sh
    fi
}

# Main execution
main() {
    log "Starting LEMP stack installation for Ubuntu $UBUNTU_VERSION"
    check_ubuntu_version
    install_dependencies
    run_installation
    log "Installation process completed!"
}

main "$@"