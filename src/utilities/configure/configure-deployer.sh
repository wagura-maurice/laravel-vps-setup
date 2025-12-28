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

log_section "Deployer User Configuration for Laravel"

# Function to get server IP address
get_server_ip() {
    local server_ip=""
    
    # Try to get IP from various methods
    # Method 1: Get primary non-loopback IP
    server_ip=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K\S+' | head -1)
    
    # Method 2: If that fails, try hostname -I
    if [ -z "$server_ip" ]; then
        server_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    fi
    
    # Method 3: If that fails, try ip addr
    if [ -z "$server_ip" ]; then
        server_ip=$(ip addr show | grep -oP 'inet \K[\d.]+' | grep -v '127.0.0.1' | head -1)
    fi
    
    # If still no IP found, use localhost
    if [ -z "$server_ip" ]; then
        server_ip="localhost"
        log_warning "Could not determine server IP, using localhost"
    else
        log_info "Server IP detected: ${server_ip}"
    fi
    
    echo "$server_ip"
}

# Function to configure deployer user for Laravel deployment
configure_deployer_for_laravel() {
    log_info "Configuring deployer user for Laravel deployment..."

    # Ensure deployer user exists
    if ! id "deployer" &>/dev/null; then
        log_error "Deployer user does not exist. Run install-system.sh first."
        return 1
    fi

    # Set up Laravel-specific directories for deployer
    sudo -u deployer -H mkdir -p /home/deployer/.ssh
    sudo -u deployer -H chmod 700 /home/deployer/.ssh
    chown -R deployer:deployer /home/deployer/.ssh
    
    # Set up Git configuration for deployer
    sudo -u deployer -H git config --global user.name "wagura-maurice"
    sudo -u deployer -H git config --global user.email "wagura465@gmail.com"
    
    # Get server IP for SSH key comment
    local server_ip
    server_ip=$(get_server_ip)
    local ssh_comment="deployer@${server_ip}"
    
    # Create SSH key pair for deployer if it doesn't exist
    if [ ! -f "/home/deployer/.ssh/id_rsa" ]; then
        log_info "Creating SSH key pair for deployer user..."
        sudo -u deployer -H bash -c "
            ssh-keygen -t rsa -b 4096 -C '${ssh_comment}' -f /home/deployer/.ssh/id_rsa -N '' -q
        "
        log_success "SSH key pair created for deployer user with comment: ${ssh_comment}"
    else
        log_info "SSH key pair already exists for deployer user"
    fi
    
    # Verify public key exists
    if [ ! -f "/home/deployer/.ssh/id_rsa.pub" ]; then
        log_error "Public key not found at /home/deployer/.ssh/id_rsa.pub"
        return 1
    else
        log_success "Public key verified at /home/deployer/.ssh/id_rsa.pub"
    fi
    
    # Set proper permissions on SSH keys
    chown deployer:deployer /home/deployer/.ssh/id_rsa /home/deployer/.ssh/id_rsa.pub 2>/dev/null || true
    chmod 600 /home/deployer/.ssh/id_rsa
    chmod 644 /home/deployer/.ssh/id_rsa.pub
    
    # Copy authorized_keys from root to deployer if root's authorized_keys exists
    if [ -f "/root/.ssh/authorized_keys" ]; then
        log_info "Copying authorized_keys from root to deployer user..."
        cp /root/.ssh/authorized_keys /home/deployer/.ssh/authorized_keys
        chown deployer:deployer /home/deployer/.ssh/authorized_keys
        chmod 600 /home/deployer/.ssh/authorized_keys
        log_success "authorized_keys copied from root to deployer user"
    else
        log_info "Root's authorized_keys not found, creating empty authorized_keys for deployer"
        touch /home/deployer/.ssh/authorized_keys
        chown deployer:deployer /home/deployer/.ssh/authorized_keys
        chmod 600 /home/deployer/.ssh/authorized_keys
    fi
    
    # Set up Laravel-specific environment variables for deployer
    sudo -u deployer -H bash -c "
        echo 'export DB_HOST=localhost' >> /home/deployer/.bashrc
        echo 'export DB_NAME=laravel_db' >> /home/deployer/.bashrc
        echo 'export DB_USER=deployer' >> /home/deployer/.bashrc
        echo 'export DB_PASS=Qwerty123!' >> /home/deployer/.bashrc
        echo 'export REDIS_HOST=localhost' >> /home/deployer/.bashrc
        echo 'export REDIS_PORT=6379' >> /home/deployer/.bashrc
    "
    
    # Ensure deployer user has proper access to web directory
    if [ -d "/var/www/html" ]; then
        sudo chown -R deployer:deployer /var/www/html
        sudo chmod -R 755 /var/www/html
        sudo -u deployer -H chmod -R 775 /var/www/html/storage
        sudo -u deployer -H chmod -R 775 /var/www/html/bootstrap/cache
    else
        log_warning "/var/www/html directory does not exist yet"
    fi
    
    # Create a Laravel deployment script for the deployer user
    sudo -u deployer -H bash -c "
        cat > /home/deployer/deploy-laravel.sh << 'EOL'
#!/bin/bash
# Laravel Deployment Script for Deployer User

# Navigate to Laravel project directory
cd /var/www/html/default_laravel_project

# Pull latest code
git pull origin main

# Install/update dependencies
composer install --no-dev --optimize-autoloader

# Run database migrations
php artisan migrate --force

# Clear and cache configurations
php artisan config:clear
php artisan route:clear
php artisan view:clear
php artisan event:clear

php artisan config:cache
php artisan route:cache
php artisan view:cache
php artisan event:cache

# Optimize Laravel
php artisan optimize:clear
php artisan optimize

# Restart PHP-FPM to apply changes
sudo systemctl reload php8.4-fpm

echo 'Laravel deployment completed successfully!'
EOL
    "
    
    # Make the deployment script executable
    sudo -u deployer -H chmod +x /home/deployer/deploy-laravel.sh
    
    # Ensure deployer can restart PHP-FPM without password prompt
    echo "deployer ALL=(ALL) NOPASSWD: /bin/systemctl reload php8.4-fpm, /bin/systemctl restart php8.4-fpm" | sudo tee /etc/sudoers.d/deployer-php-fpm
    
    log_success "Deployer user configured for Laravel deployment"
    return 0
}

# Function to set up Laravel-specific tools for deployer
setup_laravel_tools_for_deployer() {
    log_info "Setting up Laravel-specific tools for deployer user..."
    
    # Install Laravel-specific tools via Composer for deployer
    sudo -u deployer -H bash -c "
        composer global require laravel/installer
        composer global require deployer/deployer
    "
    
    # Add global Composer binaries to deployer's PATH
    echo 'export PATH=\"$PATH:$HOME/.composer/vendor/bin\"' | sudo -u deployer tee -a /home/deployer/.bashrc
    
    log_success "Laravel-specific tools installed for deployer user"
    return 0
}

# Main configuration function
main() {
    log_info "Starting deployer configuration for Laravel..."
    
    local success=true
    
    if ! configure_deployer_for_laravel; then
        log_error "Failed to configure deployer for Laravel"
        success=false
    fi
    
    if ! setup_laravel_tools_for_deployer; then
        log_error "Failed to set up Laravel tools for deployer"
        success=false
    fi
    
    if [ "${success}" = true ]; then
        log_success "Deployer user successfully configured for Laravel deployment!"
        log_info "Deployer user can now deploy Laravel applications using /home/deployer/deploy-laravel.sh"
        log_info "SSH keys generated for deployer at /home/deployer/.ssh/id_rsa"
        log_info "Deployer can restart PHP-FPM without password via sudo"
        
        # Display deployer's public SSH key for GitHub
        echo ""
        echo "=========================================="
        echo "DEPLOYER USER PUBLIC SSH KEY (for GitHub)"
        echo "=========================================="
        if [ -f "/home/deployer/.ssh/id_rsa.pub" ]; then
            cat /home/deployer/.ssh/id_rsa.pub
        else
            log_error "Public key not found at /home/deployer/.ssh/id_rsa.pub"
        fi
        echo "=========================================="
        echo ""
        log_info "Copy the public key above and add it to your GitHub repository's deploy keys"
        
        return 0
    else
        log_error "Deployer configuration completed with errors"
        return 1
    fi
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi

    main
    exit $?
fi