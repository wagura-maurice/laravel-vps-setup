#!/bin/bash
set -euo pipefail

# Load core configuration and utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
CORE_DIR="${SCRIPT_DIR}/src/core"
source "${CORE_DIR}/env-loader.sh" 2>/dev/null || {
    echo "Error: Failed to load ${CORE_DIR}/env-loader.sh" >&2
    exit 1
}

# Initialize environment and logging
load_environment
init_logging

log_section "System Installation - Complete Laravel Stack"

# Function to update system packages
update_system_packages() {
    log_info "Updating system packages..."
    
    if ! apt-get update; then
        log_error "Failed to update package lists"
        return 1
    fi
    
    if ! DEBIAN_FRONTEND=noninteractive apt-get upgrade -y; then
        log_error "Failed to upgrade packages"
        return 1
    fi
    
    log_success "System packages updated"
    return 0
}

# Function to install essential tools
install_essential_tools() {
    log_info "Installing essential tools..."
    
    local essential_packages=(
        "curl"
        "wget"
        "git"
        "unzip"
        "build-essential"
        "software-properties-common"
        "apt-transport-https"
        "ca-certificates"
        "lsb-release"
        "gnupg"
        "ufw"
        "fail2ban"
    )
    
    if ! DEBIAN_FRONTEND=noninteractive apt-get install -y "${essential_packages[@]}"; then
        log_error "Failed to install essential tools"
        return 1
    fi
    
    log_success "Essential tools installed"
    return 0
}

# Function to install Nginx
install_nginx() {
    log_info "Installing Nginx..."
    
    if ! DEBIAN_FRONTEND=noninteractive apt-get install -y nginx; then
        log_error "Failed to install Nginx"
        return 1
    fi
    
    # Start and enable Nginx
    systemctl start nginx
    systemctl enable nginx
    
    log_success "Nginx installed and enabled"
    return 0
}

# Function to install Node.js and NPM
install_nodejs() {
    log_info "Installing Node.js version 22..."
    
    # Install NodeSource repository for Node.js 22
    curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
    
    if ! DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs; then
        log_error "Failed to install Node.js"
        return 1
    fi
    
    # Verify installation
    local node_version
    local npm_version
    node_version=$(node -v)
    npm_version=$(npm -v)
    
    log_success "Node.js ${node_version} and NPM ${npm_version} installed"
    return 0
}

# Function to create deployer user
create_deployer_user() {
    log_info "Creating deployer user..."
    
    # Ensure environment is loaded
    load_environment
    
    # Create deployer user if not exists
    if ! id "deployer" &>/dev/null; then
        # Create deployer user with password from environment variables
        if ! useradd -m -s /bin/bash -p $(openssl passwd -1 "${DEPLOYER_PASS:-Qwerty123!}") deployer; then
            log_error "Failed to create deployer user"
            return 1
        fi
    else
        log_info "Deployer user already exists"
    fi
    
    # Add deployer user to sudo group
    usermod -aG sudo deployer
    
    # Set up NPM for deployer user
    sudo -u deployer mkdir -p /home/deployer/.npm
    chown -R deployer:deployer /home/deployer/.npm
    
    # Set up Composer directory for deployer user
    sudo -u deployer mkdir -p /home/deployer/.config/composer
    chown -R deployer:deployer /home/deployer/.config/composer
    
    # Set up SSH directory for deployer user
    sudo -u deployer mkdir -p /home/deployer/.ssh
    chmod 700 /home/deployer/.ssh
    chown -R deployer:deployer /home/deployer/.ssh
    
    # Set up bash configuration for deployer user
    echo 'export PATH="$PATH:/usr/local/bin:/usr/bin:/bin"' >> /home/deployer/.bashrc
    echo 'export COMPOSER_HOME="/home/deployer/.composer"' >> /home/deployer/.bashrc
    
    log_success "Deployer user created with sudo privileges"
    return 0
}

# Function to set up web directory
setup_web_directory() {
    log_info "Setting up web directory..."
    
    # Ensure environment is loaded
    load_environment
    
    # Ensure /var/www/html exists
    mkdir -p /var/www/html
    
    # Set deployer user as owner of /var/www/html using environment variable
    chown -R "${DEPLOYER_USER:-deployer}:${DEPLOYER_USER:-deployer}" /var/www/html
    chmod -R 755 /var/www/html
    
    # Ensure proper permissions for Laravel operations
    sudo -u "${DEPLOYER_USER:-deployer}" chmod -R 775 /var/www/html
    sudo -u "${DEPLOYER_USER:-deployer}" chmod -R 775 /var/www/html/storage 2>/dev/null || true
    sudo -u "${DEPLOYER_USER:-deployer}" chmod -R 775 /var/www/html/bootstrap/cache 2>/dev/null || true
    
    log_success "Web directory set up with ${DEPLOYER_USER:-deployer} ownership"
    return 0
}

# Function to configure firewall
configure_firewall() {
    log_info "Configuring firewall..."
    
    # Enable UFW firewall
    ufw --force enable
    
    # Allow SSH, HTTP, HTTPS, and MySQL
    ufw allow OpenSSH
    ufw allow 'Nginx Full'
    ufw allow 3306  # MySQL port
    
    log_success "Firewall configured"
    return 0
}


# Function to run all installations in sequence
install_complete_stack() {
    log_info "Starting complete Laravel stack installation..."
    
    # Load environment variables first
    load_environment
    
    local success=true
    
    # Update system packages
    if ! update_system_packages; then
        log_error "Failed to update system packages"
        success=false
    fi
    
    # Install essential tools
    if ! install_essential_tools; then
        log_error "Failed to install essential tools"
        success=false
    fi
    
    # Install Nginx
    if ! install_nginx; then
        log_error "Failed to install Nginx"
        success=false
    fi
    
    # Install PHP (using the existing PHP installation script)
    if [ -f "${SCRIPT_DIR}/src/utilities/install/install-php.sh" ]; then
        if ! bash "${SCRIPT_DIR}/src/utilities/install/install-php.sh"; then
            log_error "Failed to install PHP"
            success=false
        fi
    else
        log_warning "PHP installation script not found"
        success=false
    fi
    
    # Install MySQL
    if [ -f "${SCRIPT_DIR}/src/utilities/install/install-mysql.sh" ]; then
        if ! bash "${SCRIPT_DIR}/src/utilities/install/install-mysql.sh"; then
            log_error "Failed to install MySQL"
            success=false
        fi
    else
        log_warning "MySQL installation script not found"
        success=false
    fi
    
    # Install Redis
    if [ -f "${SCRIPT_DIR}/src/utilities/install/install-redis.sh" ]; then
        if ! bash "${SCRIPT_DIR}/src/utilities/install/install-redis.sh"; then
            log_error "Failed to install Redis"
            success=false
        fi
    else
        log_warning "Redis installation script not found"
        success=false
    fi
    
    # Install Certbot
    if [ -f "${SCRIPT_DIR}/src/utilities/install/install-certbot.sh" ]; then
        if ! bash "${SCRIPT_DIR}/src/utilities/install/install-certbot.sh"; then
            log_error "Failed to install Certbot"
            success=false
        fi
    else
        log_warning "Certbot installation script not found"
        success=false
    fi
    
    # Create deployer user
    if ! create_deployer_user; then
        log_error "Failed to create deployer user"
        success=false
    fi
    
    # Set up web directory
    if ! setup_web_directory; then
        log_error "Failed to set up web directory"
        success=false
    fi
    
    # Install Node.js
    if ! install_nodejs; then
        log_error "Failed to install Node.js"
        success=false
    fi
    
    # Install Composer
    if [ -f "${SCRIPT_DIR}/install/install-composer.sh" ]; then
        if ! bash "${SCRIPT_DIR}/install/install-composer.sh"; then
            log_error "Failed to install Composer"
            success=false
        fi
    else
        log_warning "Composer installation script not found"
        success=false
    fi
    
    # Configure system settings
    if [ -f "${SCRIPT_DIR}/src/utilities/configure/configure-system.sh" ]; then
        if ! bash "${SCRIPT_DIR}/src/utilities/configure/configure-system.sh"; then
            log_warning "System configuration had issues"
        fi
    fi
    
    # Configure PHP
    if [ -f "${SCRIPT_DIR}/src/utilities/configure/configure-php.sh" ]; then
        if ! bash "${SCRIPT_DIR}/src/utilities/configure/configure-php.sh"; then
            log_warning "PHP configuration had issues"
        fi
    fi
    
    # Configure Redis
    if [ -f "${SCRIPT_DIR}/src/utilities/configure/configure-redis.sh" ]; then
        if ! bash "${SCRIPT_DIR}/src/utilities/configure/configure-redis.sh"; then
            log_warning "Redis configuration had issues"
        fi
    fi
    
    # Configure Certbot
    if [ -f "${SCRIPT_DIR}/src/utilities/configure/configure-certbot.sh" ]; then
        if ! bash "${SCRIPT_DIR}/src/utilities/configure/configure-certbot.sh"; then
            log_warning "Certbot configuration had issues"
        fi
    fi
    
    # Create Laravel project
    if [ -f "${SCRIPT_DIR}/src/utilities/install/install-laravel.sh" ]; then
        if ! bash "${SCRIPT_DIR}/src/utilities/install/install-laravel.sh"; then
            log_error "Failed to install Laravel"
            success=false
        fi
    else
        log_warning "Laravel installation script not found"
        success=false
    fi
    
    # Configure firewall
    if ! configure_firewall; then
        log_warning "Firewall configuration had issues"
    fi
    
    if [ "${success}" = true ]; then
        log_success "Complete Laravel stack installation completed successfully!"
        log_info ""
        log_info "Summary of installed components:"
        log_info "  - Nginx web server"
        log_info " - PHP 8.4 with Laravel extensions"
        log_info "  - MySQL 8 database"
        log_info "  - Redis cache"
        log_info "  - Certbot for SSL certificates"
        log_info "  - Node.js 22 and NPM"
        log_info "  - Composer dependency manager"
        log_info "  - Laravel framework"
        log_info "  - Deployer user with sudo privileges"
        log_info "  - Firewall configuration"
        log_info ""
        log_info "The Laravel application is available at /var/www/html/default_laravel_project"
        log_info "Public directory is at /var/www/html/default_laravel_project/public"
        log_info ""
        log_info "Deployer user credentials:"
        log_info "  - Username: deployer"
        log_info "  - Password: Qwerty123!"
        log_info "  - Home directory: /home/deployer"
        log_info "  - Has sudo privileges"
        log_info ""
        log_info "MySQL credentials:"
        log_info "  - Root password: !Qwerty123!"
        log_info "  - Deployer database user password: Qwerty123!"
        return 0
    else
        log_error "Complete Laravel stack installation completed with errors"
        return 1
    fi
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi

    install_complete_stack
    exit $?
fi
