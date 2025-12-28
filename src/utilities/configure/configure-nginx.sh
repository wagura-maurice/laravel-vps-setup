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

log_section "Nginx Configuration for Laravel"

# Function to configure Nginx for Laravel
configure_nginx_for_laravel() {
    log_info "Configuring Nginx for Laravel..."

    # Remove default Nginx configuration
    rm -f /etc/nginx/sites-enabled/default

    # Ensure environment is loaded
    load_environment
    
    # Get values from environment with defaults
    local domain_name="${DOMAIN_NAME:-localhost}"
    local project_name="${LARAVEL_PROJECT_NAME:-default_laravel_project}"

    # Create Nginx configuration for Laravel with domain from environment
    cat > /etc/nginx/sites-available/laravel <<EOL
server {
    listen 80;
    server_name ${domain_name};  # Domain from environment
    root /var/www/html/${project_name}/public;
    index index.php index.html index.htm;

    # Handle Laravel's pretty URLs
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    # PHP processing
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.4-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    # Deny access to hidden files
    location ~ /\.ht {
        deny all;
    }

    # Deny access to sensitive Laravel files
    location ~ /\.env$ {
        deny all;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }

    # Optimize static file serving
    location ~* \.(css|js|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    
    # Logging
    access_log /var/log/nginx/laravel_access.log;
    error_log /var/log/nginx/laravel_error.log;
}
EOL

    # Enable the Laravel site
    ln -s /etc/nginx/sites-available/laravel /etc/nginx/sites-enabled/

    # Test Nginx configuration
    nginx -t

    # Restart Nginx to apply changes
    systemctl restart nginx

    log_success "Nginx configured for Laravel"
    return 0
}

# Main configuration function
configure_nginx_main() {
    log_info "Starting Nginx configuration for Laravel..."

    if ! configure_nginx_for_laravel; then
        log_error "Failed to configure Nginx for Laravel"
        return 1
    fi

    log_success "Nginx configuration for Laravel completed successfully!"
    log_info "Laravel application directory: /var/www/html/default_laravel_project"
    log_info "Public directory is at /var/www/html/default_laravel_project/public"
    log_info "Nginx configuration file: /etc/nginx/sites-available/laravel"
    return 0
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi

    configure_nginx_main
    exit $?
fi