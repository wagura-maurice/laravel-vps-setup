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

log_section "Laravel Project Installation"


# Function to install Laravel project
install_laravel_project() {
    log_info "Installing Laravel project..."

    # Ensure environment is loaded
    load_environment

    # Ensure the web directory exists
    sudo mkdir -p /var/www/html
    sudo chown -R deployer:deployer /var/www/html
    sudo chmod -R 755 /var/www/html

    # Ensure the deployer user has proper Composer configuration
    sudo -u deployer -H mkdir -p /home/deployer/.config/composer
    sudo -u deployer -H touch /home/deployer/.composer/autoload_classmap.php
    
    # Create Laravel project as deployer user with project name from environment
    local project_name="${LARAVEL_PROJECT_NAME:-default_laravel_project}"
    sudo -u deployer -H bash -c "
        cd /var/www/html
        if [ ! -d '${project_name}' ]; then
            /usr/local/bin/composer create-project laravel/laravel ${project_name}
        else
            echo 'Laravel project already exists in /var/www/html/${project_name}'
        fi
    "

    # Set proper permissions for Laravel directories
    if [ -d "/var/www/html/${project_name}" ]; then
        sudo chown -R deployer:deployer /var/www/html/${project_name}
        sudo chmod -R 755 /var/www/html/${project_name}
        sudo -u deployer -H chmod -R 775 /var/www/html/${project_name}/storage
        sudo -u deployer -H chmod -R 775 /var/www/html/${project_name}/bootstrap/cache
    else
        log_error "Laravel project was not created successfully"
        return 1
    fi

    log_success "Laravel project installed successfully in /var/www/html/${project_name}"
    return 0
}

# Function to configure Laravel environment
configure_laravel_env() {
    log_info "Configuring Laravel environment..."

    # Ensure environment is loaded
    load_environment

    local project_name="${LARAVEL_PROJECT_NAME:-default_laravel_project}"
    local project_path="/var/www/html/${project_name}"
    
    if [ ! -f "${project_path}/.env" ]; then
        log_error "Laravel project not found at ${project_path}"
        return 1
    fi

    # Copy .env.example to .env if .env doesn't exist
    if [ ! -f "${project_path}/.env" ]; then
        sudo -u deployer -H cp "${project_path}/.env.example" "${project_path}/.env"
    fi

    # Generate application key
    sudo -u deployer -H bash -c "
        cd ${project_path}
        php artisan key:generate
    "

    # Update .env with database credentials and settings from environment variables
    # Using root user with hardcoded password "Rtcv39$$"
    # APP_URL is read directly from the project's .env file (line 22)
    sudo -u deployer -H bash -c "
        sed -i \"s/DB_DATABASE=.*/DB_DATABASE=${DB_NAME:-laravel_db}/\" ${project_path}/.env
        sed -i \"s/DB_USERNAME=.*/DB_USERNAME=root/\" ${project_path}/.env
        sed -i \"s/DB_PASSWORD=.*/DB_PASSWORD=Rtcv39\$\$/\" ${project_path}/.env
        sed -i \"s/APP_ENV=.*/APP_ENV=${APP_ENV:-production}/\" ${project_path}/.env
        sed -i \"s/APP_DEBUG=.*/APP_DEBUG=${APP_DEBUG:-false}/\" ${project_path}/.env
        sed -i \"s|APP_URL=.*|APP_URL=${APP_URL}|\" ${project_path}/.env
    "
    
    log_info "APP_URL configured as: ${APP_URL}"

    log_success "Laravel environment configured"
    return 0
}

# Function to optimize Laravel
optimize_laravel() {
    log_info "Optimizing Laravel application..."

    # Ensure environment is loaded
    load_environment

    # Run Laravel optimization commands as deployer user
    sudo -u deployer -H bash -c "
        cd /var/www/html/${LARAVEL_PROJECT_NAME}
        php artisan config:cache
        php artisan route:cache
        php artisan view:cache
        php artisan event:cache
        php artisan optimize:clear
    "

    log_success "Laravel application optimized"
    return 0
}

# Function to set up Laravel cron jobs
setup_laravel_cron() {
    log_info "Setting up Laravel cron jobs..."

    # Ensure environment is loaded
    load_environment

    # Add Laravel scheduler to the deployer user's crontab
    local project_name="${LARAVEL_PROJECT_NAME:-default_laravel_project}"
    (sudo -u deployer crontab -l 2>/dev/null; echo "* * * * * cd /var/www/html/${project_name} && php artisan schedule:run >> /dev/null 2>&1") | sudo -u deployer crontab -

    log_success "Laravel cron jobs set up for deployer user"
    return 0
}

# Main installation function
install_laravel_main() {
    log_info "Starting Laravel project installation..."

    # Load environment variables first
    load_environment

    if ! install_laravel_project; then
        log_error "Failed to install Laravel project"
        return 1
    fi

    if ! configure_laravel_env; then
        log_error "Failed to configure Laravel environment"
        return 1
    fi

    if ! optimize_laravel; then
        log_warning "Laravel optimization had issues"
    fi

    if ! setup_laravel_cron; then
        log_warning "Failed to set up Laravel cron jobs"
    fi

    local project_name="${LARAVEL_PROJECT_NAME:-default_laravel_project}"
    log_success "Laravel project installation completed successfully!"
    log_info "Laravel application is available at /var/www/html/${project_name}"
    log_info "Public directory is at /var/www/html/${project_name}/public"
    log_info "Ensure your Nginx configuration points to the correct public directory"
    return 0
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi

    install_laravel_main
    exit $?
fi