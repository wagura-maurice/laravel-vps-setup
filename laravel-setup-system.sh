#!/bin/bash
set -euo pipefail

# Laravel VPS Setup Script
# This script sets up a complete Laravel production environment on a fresh Ubuntu 22.04 VPS
# It installs and configures all necessary components for a production-ready Laravel application
# This is the main entry point that coordinates all the modular installation scripts

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root"
    exit 1
fi

# Check if sudo is available
if ! command -v sudo &> /dev/null; then
    log_error "sudo is required but not installed. Please install sudo first."
    exit 1
fi

# Check if this is Ubuntu 22.04
if ! grep -q "Ubuntu 22.04" /etc/os-release 2>/dev/null; then
    log_warning "This script is designed for Ubuntu 22.04. Proceeding anyway, but results may vary."
fi

# Load core environment loader with error handling
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="${SCRIPT_DIR}/src/core"
LOG_FILE="/tmp/laravel-setup-$(date +%s).log"

# Function to log errors to file and stderr
log_to_file() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE" >&2
}

# Check if env-loader.sh exists and is readable
if [ ! -f "${CORE_DIR}/env-loader.sh" ]; then
    log_error "Environment loader not found at ${CORE_DIR}/env-loader.sh"
    exit 1
fi

# Source the environment loader with error handling
if ! source "${CORE_DIR}/env-loader.sh" 2>>"$LOG_FILE"; then
    log_error "Failed to load environment from ${CORE_DIR}/env-loader.sh"
    log_error "Check $LOG_FILE for details"
    exit 1
fi

# Verify environment was loaded correctly
if [ -z "${ENV_LOADED:-}" ]; then
    log_error "Environment was not loaded properly. Check $LOG_FILE for errors."
    exit 1
fi

# Main installation function - executes the modular system
main() {
    log "Starting Laravel VPS setup using modular system..."
    
    # Load environment variables first
    load_environment

    # Define the order of installation
    local install_scripts=(
        "src/utilities/install/install-system.sh"
        "src/utilities/install/install-php.sh"
        "src/utilities/install/install-mysql.sh"
        "src/utilities/install/install-redis.sh"
        "src/utilities/install/install-composer.sh"
        "src/utilities/install/install-laravel.sh"
        "src/utilities/configure/configure-nginx.sh"
        "src/utilities/configure/configure-php.sh"
        "src/utilities/configure/configure-redis.sh"
        "src/utilities/configure/configure-deployer.sh"
        "src/utilities/install/install-certbot.sh"
    )

    # Execute each installation script in sequence
    for script in "${install_scripts[@]}"; do
        if [ -f "$script" ]; then
            log "Executing $script..."
            bash "$script"
            if [ $? -eq 0 ]; then
                log_success "$script executed successfully"
            else
                log_error "Failed to execute $script"
                exit 1
            fi
        else
            log_warning "Script not found: $script (skipping)"
        fi
    done

    # Get values from environment
    local project_name="${LARAVEL_PROJECT_NAME:-default_laravel_project}"
    local domain_name="${DOMAIN_NAME:-localhost}"
    
    log_success "Laravel VPS setup completed successfully!"
    log_success "Laravel application directory: /var/www/html/${project_name}"
    log_success "Public directory: /var/www/html/${project_name}/public"
    log_success "Domain configured: ${domain_name}"
    log_success "MySQL root password: ${DB_ROOT_PASS:-!Qwerty123!}"
    log_success "Management script: laravel-manager {start|stop|restart|status}"
    
    if [ "${domain_name}" != "localhost" ]; then
        log "For SSL certificate, run: sudo certbot --nginx -d ${domain_name}"
    else
        log_warning "Domain is set to localhost. Update DOMAIN_NAME in .env file for production use."
        log_warning "For SSL certificate, run: sudo certbot --nginx -d your-domain.com"
    fi
}

# Run main function
main "$@"