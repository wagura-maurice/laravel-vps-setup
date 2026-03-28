#!/bin/bash

#==============================================================================
# Complete LEMP Stack Installation Script (Ubuntu/Debian)
# Installation Process: System Update → Firewall → Utilities → MySQL → Nginx → PHP 8.4 → Deployer User → Composer → Node.js 22 → PM2 → Redis → Fail2Ban → Verification
#==============================================================================

set -e  # Exit on any error
set -u  # Exit on undefined variable
set -o pipefail  # Exit on pipe failures

#==============================================================================
# CONFIGURATION SECTION - SET THESE VALUES BEFORE RUNNING
#==============================================================================

# MySQL Configuration
MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-$(openssl rand -base64 32)}"

# Deployer User Configuration
DEPLOYER_USERNAME="deployer"
DEPLOYER_PASSWORD="${DEPLOYER_PASSWORD:-$(openssl rand -base64 32)}"
DEPLOYER_EMAIL="business@waguramaurice.com"
DEPLOYER_FULLNAME="Wagura Maurice"

# Redis Configuration
REDIS_PASSWORD="${REDIS_PASSWORD:-$(openssl rand -base64 32)}"

# SSH Public Key for Deployer (replace with your actual key)
DEPLOYER_SSH_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC9h81rG/s+3hJ3nTEpxE78O+MFs1NtPfU+pn4/ZX9hs9PxoLkUrKmnLSqzNBlK1FKL3fz1dgL1WTh21rVb7qEmnh/7kBaiAObl/s4+M7BxZwwwIxj35LZOKoyAozcjdURpnblB8g7aUJ4Yayn466isFECo9BxDSfV07OOKOxbGC5GFgnkxU//XowGXgHzgJ3k76JBPFNV+gDQRa3As6XMqApn2aNAGs0wEwhxJa4FX0sEVcvZ84HUfjI7vDx6OueD5r8qgVsectHzNVAutUAQXOUfiahgOPKwlopqXGyvAfW2lirI1j9SPqBJquWelhODgG2WKTFE8AZGpXLhofEYtUSTgL/b8gca3xlZ+cfiqWMn0283oYoLBxNotsdGg4fY20EZBA0WmiyeTzYFo1RVCPpNxjJ7jUm+UQZ9wNaQsKxS0q1emG4lHusz26KKUjgCaoTgjrCBk2fwBsFkGKgvTDaiHelMgM7y5jSlspX1r45kZb5tfdxTDTBbQaOZDD5osjNXRlfcwXMP0WqRM69YOe+8Kv6YqQu+L3uv3y6eT9vGR3cv7LbTNEg2uKV3kgLT528fd9FT8fVpBFbmyeDoqQ2VJaOTkNFe7y4BY7o/v0XEFSomUXjYOKnavFdxHwXI2gA/ke2hmQYj3qvhBPdiIYujwB0FW/JTPdqnV0DACkw== business@waguramaurice.com"

# Timezone Configuration
TIMEZONE="Africa/Nairobi"

# PHP Configuration
PHP_VERSION="8.4"

# Node.js Version
NODE_MAJOR=22

# MySQL Remote Access Configuration
# Set to "any" to allow connections from any IP (NOT RECOMMENDED - security risk)
# Set to specific IPs comma-separated: "192.168.1.100,10.0.0.50"
# Leave empty "" for localhost only
MYSQL_ALLOW_REMOTE="any"  # WARNING: This allows root login from ANY IP!

#==============================================================================
# LOGGING FUNCTIONS
#==============================================================================

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO:${NC} $*"
}

log_success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS:${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $*"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $*"
}

#==============================================================================
# SAVE CREDENTIALS FUNCTION
#==============================================================================

save_credentials() {
    local CREDS_FILE="/root/lemp_credentials.txt"
    
    cat > "$CREDS_FILE" <<EOF
================================================================================
LEMP STACK INSTALLATION CREDENTIALS
Generated: $(date +'%Y-%m-%d %H:%M:%S')
================================================================================

MySQL Root Password: $MYSQL_ROOT_PASSWORD

Deployer User Credentials:
  Username: $DEPLOYER_USERNAME
  Password: $DEPLOYER_PASSWORD
  
Redis Password: $REDIS_PASSWORD

IMPORTANT: 
- Store these credentials securely
- Delete this file after saving: rm $CREDS_FILE
- Change passwords regularly for security

================================================================================
EOF

    chmod 600 "$CREDS_FILE"
    log_success "Credentials saved to: $CREDS_FILE"
}

#==============================================================================
# SYSTEM UPDATE
#==============================================================================

update_system() {
    log_info "Updating and upgrading system packages..."
    sudo apt update -y
    sudo apt upgrade -y
    log_success "System updated successfully"
}

#==============================================================================
# FIREWALL CONFIGURATION
#==============================================================================

configure_firewall() {
    log_info "Installing and configuring UFW firewall..."
    
    sudo apt install ufw -y
    
    # Allow SSH, HTTP, HTTPS
    sudo ufw allow 22/tcp
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    
    # MySQL port configuration based on MYSQL_ALLOW_REMOTE setting
    if [ "$MYSQL_ALLOW_REMOTE" = "any" ]; then
        log_warning "⚠️  SECURITY WARNING: Opening MySQL port 3306 to ALL IPs!"
        log_warning "⚠️  Anyone with the root password can access your database from anywhere!"
        sudo ufw allow 3306/tcp
        log_info "MySQL port 3306 open to all IPs"
    elif [ -n "$MYSQL_ALLOW_REMOTE" ]; then
        log_info "Configuring MySQL access for specific IPs..."
        IFS=',' read -ra IPS <<< "$MYSQL_ALLOW_REMOTE"
        for ip in "${IPS[@]}"; do
            sudo ufw allow from "$ip" to any port 3306
            log_info "Allowed MySQL access from: $ip"
        done
    else
        log_info "MySQL will only be accessible from localhost (port 3306 blocked externally)"
    fi
    
    sudo ufw --force enable
    log_success "Firewall configured successfully"
}

#==============================================================================
# MYSQL INSTALLATION AND CONFIGURATION
#==============================================================================

install_mysql() {
    log_info "Installing MySQL Server..."
    
    sudo apt update
    sudo apt install mysql-server -y
    
    log_info "Securing MySQL installation..."
    
    # Configure MySQL for remote access if needed
    if [ "$MYSQL_ALLOW_REMOTE" = "any" ] || [ -n "$MYSQL_ALLOW_REMOTE" ]; then
        log_warning "⚠️  Configuring MySQL for REMOTE ACCESS"
        
        # Secure MySQL and create remote root user
        sudo mysql <<EOF
-- Set root password for localhost
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASSWORD';

-- Create root user for remote access (ALL hosts)
CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASSWORD';
ALTER USER 'root'@'%' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASSWORD';

-- Grant all privileges to remote root
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;

-- Remove anonymous users
DELETE FROM mysql.user WHERE User='';

-- Remove test database
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';

-- Reload privilege tables
FLUSH PRIVILEGES;
EOF

        # Bind to all interfaces
        sudo sed -i 's/^bind-address\s*=.*/bind-address = 0.0.0.0/' /etc/mysql/mysql.conf.d/mysqld.cnf
        sudo sed -i 's/^mysqlx-bind-address\s*=.*/mysqlx-bind-address = 0.0.0.0/' /etc/mysql/mysql.conf.d/mysqld.cnf
        log_warning "⚠️  MySQL configured to accept connections from ANY IP address"
        
    else
        log_info "Configuring MySQL for localhost access only..."
        
        # Secure MySQL installation (localhost only)
        sudo mysql <<EOF
-- Set root password
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASSWORD';

-- Remove anonymous users
DELETE FROM mysql.user WHERE User='';

-- Disallow root login remotely
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');

-- Remove test database
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';

-- Reload privilege tables
FLUSH PRIVILEGES;
EOF

        # Bind to localhost only
        sudo sed -i 's/^bind-address\s*=.*/bind-address = 127.0.0.1/' /etc/mysql/mysql.conf.d/mysqld.cnf
        log_info "MySQL configured for localhost only (secure)"
    fi
    
    sudo systemctl restart mysql
    sudo systemctl enable mysql
    
    log_success "MySQL installed and configured successfully"
}

#==============================================================================
# NGINX INSTALLATION
#==============================================================================

install_nginx() {
    log_info "Installing Nginx..."
    
    sudo apt install nginx -y
    sudo systemctl start nginx
    sudo systemctl enable nginx
    
    # Configure Nginx virtual host for PHP
    log_info "Configuring Nginx virtual host..."
    
    # Create default virtual host configuration
    sudo tee /etc/nginx/sites-available/default > /dev/null <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    root /var/www/html;
    index index.php index.html index.htm index.nginx-debian.html;
    server_name _;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php${PHP_VERSION}-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

    # Backup original configuration and create new one
    log_info "Backing up original Nginx configuration..."
    if [ -f "/etc/nginx/sites-available/default" ]; then
        sudo cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.lemp_backup
        log_success "Original Nginx config backed up to default.lemp_backup"
    fi
    
    # Remove default symlink if exists and create new one
    sudo rm -f /etc/nginx/sites-enabled/default
    sudo ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/
    
    # Test Nginx configuration
    sudo nginx -t
    
    # Restart Nginx to apply configuration
    sudo systemctl restart nginx
    
    # Configure client_max_body_size in nginx.conf to match PHP post_max_size
    log_info "Configuring Nginx client_max_body_size..."
    NGINX_CONF="/etc/nginx/nginx.conf"
    
    # Define PHP_INI path (same as in PHP function)
    PHP_INI="/etc/php/${PHP_VERSION}/fpm/php.ini"
    
    # Get the post_max_size value from PHP configuration
    POST_MAX_SIZE=$(grep "post_max_size =" "$PHP_INI" | cut -d'=' -f2 | tr -d ' ')
    log_info "Setting client_max_body_size to $POST_MAX_SIZE (matching PHP post_max_size)"
    
    # Backup nginx.conf
    if [ -f "$NGINX_CONF" ]; then
        sudo cp "$NGINX_CONF" "${NGINX_CONF}.backup"
        log_success "Nginx main config backed up"
    fi
    
    # Add client_max_body_size to http block in nginx.conf
    if grep -q "client_max_body_size" "$NGINX_CONF"; then
        # Update existing setting
        sudo sed -i "s/client_max_body_size .*/client_max_body_size $POST_MAX_SIZE;/" "$NGINX_CONF"
    else
        # Add new setting after http { line
        sudo sed -i "/http {/a \    client_max_body_size $POST_MAX_SIZE;" "$NGINX_CONF"
    fi
    
    # Test Nginx configuration
    if sudo nginx -t; then
        sudo systemctl restart nginx
        log_success "Nginx client_max_body_size configured to $POST_MAX_SIZE"
    else
        log_error "Nginx configuration test failed, restoring backup"
        if [ -f "${NGINX_CONF}.backup" ]; then
            sudo cp "${NGINX_CONF}.backup" "$NGINX_CONF"
            sudo systemctl restart nginx
        fi
    fi
    
    log_success "Nginx installed and configured successfully"
}

#==============================================================================
# PHP INSTALLATION AND CONFIGURATION
#==============================================================================

install_php() {
    log_info "Installing PHP $PHP_VERSION and extensions..."
    
    # Install prerequisite
    sudo apt install -y software-properties-common
    
    # Add Ondřej PHP PPA WITHOUT automatic update
    log_info "Adding Ondřej PHP PPA..."
    sudo add-apt-repository -y -n ppa:ondrej/php
    
    # Wait for any lingering apt locks (just in case)
    log_info "Waiting for apt locks to release if needed..."
    while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || \
          sudo fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do
        log_info "Apt lock detected, waiting 5 seconds..."
        sleep 5
    done
    
    # Now safely update and install
    sudo apt update -y
    
    # Install PHP and extensions
    sudo apt install -y \
        php${PHP_VERSION} \
        php${PHP_VERSION}-fpm \
        php${PHP_VERSION}-cli \
        php${PHP_VERSION}-common \
        php${PHP_VERSION}-mysql \
        php${PHP_VERSION}-zip \
        php${PHP_VERSION}-gd \
        php${PHP_VERSION}-mbstring \
        php${PHP_VERSION}-curl \
        php${PHP_VERSION}-xml \
        php${PHP_VERSION}-bcmath \
        php${PHP_VERSION}-intl \
        php${PHP_VERSION}-readline \
        php${PHP_VERSION}-sqlite3 \
        php${PHP_VERSION}-xsl \
        php${PHP_VERSION}-enchant \
        php${PHP_VERSION}-odbc \
        php${PHP_VERSION}-pgsql \
        php${PHP_VERSION}-pspell \
        php${PHP_VERSION}-snmp \
        php${PHP_VERSION}-tidy \
        php${PHP_VERSION}-xdebug
    
    # Rest of your PHP configuration (unchanged)
    log_info "Configuring PHP settings..."
    
    PHP_INI="/etc/php/${PHP_VERSION}/fpm/php.ini"
    
    sudo sed -i 's/upload_max_filesize = .*/upload_max_filesize = 32M/' "$PHP_INI"
    sudo sed -i 's/file_uploads = .*/file_uploads = On/' "$PHP_INI"
    sudo sed -i 's/allow_url_fopen = .*/allow_url_fopen = On/' "$PHP_INI"
    sudo sed -i "s@;*date.timezone =.*@date.timezone = $TIMEZONE@" "$PHP_INI"
    sudo sed -i 's/post_max_size = .*/post_max_size = 48M/' "$PHP_INI"
    sudo sed -i 's/memory_limit = .*/memory_limit = 256M/' "$PHP_INI"
    sudo sed -i 's/max_execution_time = .*/max_execution_time = 600/' "$PHP_INI"
    sudo sed -i 's/;*max_input_vars = .*/max_input_vars = 5000/' "$PHP_INI"
    sudo sed -i 's/max_input_time = .*/max_input_time = 1000/' "$PHP_INI"
    sudo sed -i 's/;*cgi.fix_pathinfo=.*/cgi.fix_pathinfo=0/' "$PHP_INI"
    sudo sed -i 's/;*max_file_uploads = .*/max_file_uploads = 50/' "$PHP_INI"

    # OPcache Configuration
    log_info "Configuring OPcache..."
    OPCACHE_INI="/etc/php/${PHP_VERSION}/cli/conf.d/10-opcache.ini"
    
    if [ -f "$OPCACHE_INI" ]; then
        sudo sed -i 's/;*opcache\.enable=.*/opcache.enable=1/' "$OPCACHE_INI"
        sudo sed -i 's/;*opcache\.memory_consumption=.*/opcache.memory_consumption=256/' "$OPCACHE_INI"
        sudo sed -i 's/;*opcache\.max_accelerated_files=.*/opcache.max_accelerated_files=20000/' "$OPCACHE_INI"
        sudo sed -i 's/;*opcache\.revalidate_freq=.*/opcache.revalidate_freq=0/' "$OPCACHE_INI"
    fi
    
    # FPM Pool Configuration
    log_info "Configuring PHP-FPM pool..."
    FPM_POOL="/etc/php/${PHP_VERSION}/fpm/pool.d/www.conf"
    
    sudo cp "$FPM_POOL" "${FPM_POOL}.bak"
    
    sudo sed -i 's/^;*\s*pm\s*=.*/pm = dynamic/' "$FPM_POOL"
    sudo sed -i 's/^;*\s*pm\.max_children\s*=.*/pm.max_children = 50/' "$FPM_POOL"
    sudo sed -i 's/^;*\s*pm\.start_servers\s*=.*/pm.start_servers = 10/' "$FPM_POOL"
    sudo sed -i 's/^;*\s*pm\.min_spare_servers\s*=.*/pm.min_spare_servers = 5/' "$FPM_POOL"
    sudo sed -i 's/^;*\s*pm\.max_spare_servers\s*=.*/pm.max_spare_servers = 35/' "$FPM_POOL"
    
    sudo systemctl restart php${PHP_VERSION}-fpm
    sudo systemctl enable php${PHP_VERSION}-fpm
    
    log_success "PHP installed and configured successfully"
}

#==============================================================================
# UTILITIES INSTALLATION
#==============================================================================

install_utilities() {
    log_info "Installing system utilities..."
    
    sudo apt install -y curl wget git acl unzip ca-certificates gnupg python3 certbot python3-certbot-nginx
    
    log_success "Utilities installed successfully"
}

#==============================================================================
# DEPLOYER USER SETUP
#==============================================================================

setup_deployer_user() {
    log_info "Setting up deployer user: $DEPLOYER_USERNAME"
    
    # Create deployer user
    if id "$DEPLOYER_USERNAME" &>/dev/null; then
        log_warning "User $DEPLOYER_USERNAME already exists, skipping creation"
    else
        sudo adduser --gecos "" --disabled-password "$DEPLOYER_USERNAME"
        echo "$DEPLOYER_USERNAME:$DEPLOYER_PASSWORD" | sudo chpasswd
        log_success "User $DEPLOYER_USERNAME created"
    fi
    
    # Add to groups
    sudo usermod -aG sudo "$DEPLOYER_USERNAME"
    sudo usermod -aG www-data "$DEPLOYER_USERNAME"
    sudo chfn -o umask=022 "$DEPLOYER_USERNAME"
    
    # Set up /var/www/html
    log_info "Setting up web directory..."
    sudo mkdir -p /var/www/html
    sudo chown "$DEPLOYER_USERNAME:www-data" /var/www/html
    sudo chmod 775 /var/www/html
    sudo chmod g+s /var/www/html
    
    # SSH key setup
    log_info "Configuring SSH keys for $DEPLOYER_USERNAME..."
    sudo -u "$DEPLOYER_USERNAME" mkdir -p /home/$DEPLOYER_USERNAME/.ssh
    sudo -u "$DEPLOYER_USERNAME" chmod 700 /home/$DEPLOYER_USERNAME/.ssh
    
    # Get server IP for SSH key comment
    SERVER_IP=$(hostname -I | awk '{print $1}')
    SSH_KEY_COMMENT="$DEPLOYER_USERNAME@$SERVER_IP"
    
    # Generate SSH key pair with deployer@SERVER_IP as comment
    if [ ! -f "/home/$DEPLOYER_USERNAME/.ssh/id_rsa" ]; then
        sudo -u "$DEPLOYER_USERNAME" ssh-keygen -t rsa -b 4096 -N "" -f /home/$DEPLOYER_USERNAME/.ssh/id_rsa -q -C "$SSH_KEY_COMMENT"
        log_success "SSH key generated with comment: $SSH_KEY_COMMENT"
    fi
    
    # Add authorized key
    sudo -u "$DEPLOYER_USERNAME" touch /home/$DEPLOYER_USERNAME/.ssh/authorized_keys
    sudo -u "$DEPLOYER_USERNAME" chmod 600 /home/$DEPLOYER_USERNAME/.ssh/authorized_keys
    
    echo "$DEPLOYER_SSH_KEY" | sudo -u "$DEPLOYER_USERNAME" tee -a /home/$DEPLOYER_USERNAME/.ssh/authorized_keys > /dev/null
    
    # Git configuration
    log_info "Configuring Git for $DEPLOYER_USERNAME..."
    sudo -u "$DEPLOYER_USERNAME" git config --global color.ui true
    sudo -u "$DEPLOYER_USERNAME" git config --global user.name "$DEPLOYER_FULLNAME"
    sudo -u "$DEPLOYER_USERNAME" git config --global user.email "$DEPLOYER_EMAIL"
    
    log_success "Deployer user configured successfully"
}

#==============================================================================
# COMPOSER INSTALLATION
#==============================================================================

install_composer() {
    log_info "Installing Composer..."
    
    cd /tmp
    php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
    
    EXPECTED_CHECKSUM="$(wget -q -O - https://composer.github.io/installer.sig)"
    ACTUAL_CHECKSUM="$(php -r "echo hash_file('sha384', 'composer-setup.php');")"
    
    if [ "$EXPECTED_CHECKSUM" != "$ACTUAL_CHECKSUM" ]; then
        log_error "Composer installer corrupt"
        rm composer-setup.php
        return 1
    fi
    
    sudo php composer-setup.php --install-dir=/usr/local/bin --filename=composer
    php -r "unlink('composer-setup.php');"
    
    # Make composer available to deployer
    sudo -u "$DEPLOYER_USERNAME" mkdir -p /home/$DEPLOYER_USERNAME/.local/bin
    sudo ln -sf /usr/local/bin/composer /home/$DEPLOYER_USERNAME/.local/bin/composer
    sudo chown -R "$DEPLOYER_USERNAME:$DEPLOYER_USERNAME" /home/$DEPLOYER_USERNAME/.local
    
    # Add to PATH
    if ! grep -q '.local/bin' /home/$DEPLOYER_USERNAME/.bashrc; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' | sudo tee -a /home/$DEPLOYER_USERNAME/.bashrc
    fi
    
    log_success "Composer installed successfully"
}

#==============================================================================
# NODE.JS INSTALLATION
#==============================================================================

install_nodejs() {
    log_info "Installing Node.js $NODE_MAJOR..."
    
    # Add NodeSource repository
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | \
        sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
    
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | \
        sudo tee /etc/apt/sources.list.d/nodesource.list
    
    sudo apt update
    sudo apt install nodejs -y
    
    log_success "Node.js $(node -v) installed successfully"
}

#==============================================================================
# PM2 INSTALLATION
#==============================================================================

install_pm2() {
    log_info "Installing PM2 process manager globally..."
    
    # Install PM2 globally
    if ! npm install -g pm2@latest; then
        log_error "Failed to install PM2"
        return 1
    fi

    # Verify installation
    if ! command -v pm2 > /dev/null; then
        log_error "PM2 command not found after installation"
        return 1
    fi

    log_info "Setting up PM2 for user: $DEPLOYER_USERNAME..."
    
    # Create and set permissions for PM2 home
    local pm2_home="/home/$DEPLOYER_USERNAME/.pm2"
    
    # Remove existing .pm2 directory if it exists
    sudo -u "$DEPLOYER_USERNAME" rm -rf "$pm2_home"
    
    # Create new directory with correct permissions
    sudo -u "$DEPLOYER_USERNAME" mkdir -p "$pm2_home"
    
    # Set proper ownership and permissions
    chown -R "$DEPLOYER_USERNAME:$DEPLOYER_USERNAME" "/home/$DEPLOYER_USERNAME"
    chmod 755 "/home/$DEPLOYER_USERNAME"
    chmod 700 "$pm2_home"
    
    # Initialize PM2 for the deployer user
    log_info "Initializing PM2 for $DEPLOYER_USERNAME..."
    sudo -u "$DEPLOYER_USERNAME" bash -c "export PM2_HOME='$pm2_home' && pm2 ping" || {
        log_info "Setting up PM2 startup..."
        sudo -u "$DEPLOYER_USERNAME" bash -c "export PM2_HOME='$pm2_home' && pm2 startup" || {
            log_warning "PM2 startup command failed, but continuing..."
        }
    }

    log_success "PM2 installation completed for $DEPLOYER_USERNAME"
    log_info ""
    log_info "To use PM2:"
    log_info "1. Switch to deployer user: sudo -u $DEPLOYER_USERNAME -i"
    log_info "2. Start your app: pm2 start app.js --name 'my-app'"
    log_info "3. Save process list: pm2 save"
    log_info "4. Set up startup: pm2 startup"
    
    return 0
}

#==============================================================================
# REDIS INSTALLATION AND CONFIGURATION
#==============================================================================

install_redis() {
    log_info "Installing Redis Server..."
    
    sudo apt update
    sudo apt install redis-server -y
    
    log_info "Configuring Redis..."
    
    # Set password
    sudo sed -i "s/^# requirepass foobared/requirepass $REDIS_PASSWORD/" /etc/redis/redis.conf
    
    # Bind to localhost only (secure default)
    sudo sed -i 's/^bind .*/bind 127.0.0.1 ::1/' /etc/redis/redis.conf
    
    # Restart and enable
    sudo systemctl restart redis-server
    sudo systemctl enable redis-server
    
    log_success "Redis installed and configured successfully"
}

#==============================================================================
# FAIL2BAN INSTALLATION (Optional but Recommended)
#==============================================================================

install_fail2ban() {
    log_info "Installing Fail2Ban for security..."
    
    sudo apt install fail2ban -y
    sudo systemctl start fail2ban
    sudo systemctl enable fail2ban
    
    log_success "Fail2Ban installed successfully"
}

#==============================================================================
# INSTALLATION VERIFICATION
#==============================================================================

verify_installation() {
    log_info "Verifying installation success..."
    log_info "============================================"
    
    local verification_failed=0
    
    # Test Nginx
    log_info "Testing Nginx..."
    if systemctl is-active --quiet nginx && systemctl is-enabled --quiet nginx; then
        log_success "✓ Nginx is running and enabled"
    else
        log_error "✗ Nginx verification failed"
        verification_failed=1
    fi
    
    # Test MySQL with credentials
    log_info "Testing MySQL connection with credentials..."
    if mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "SELECT 1;" >/dev/null 2>&1; then
        log_success "✓ MySQL connection successful with root password"
        
        # Test remote access if configured
        if [ "$MYSQL_ALLOW_REMOTE" = "any" ] || [ -n "$MYSQL_ALLOW_REMOTE" ]; then
            log_info "Testing MySQL remote access configuration..."
            if mysql -u root -p"$MYSQL_ROOT_PASSWORD" -h "$(hostname -I | awk '{print $1}')" -e "SELECT 1;" >/dev/null 2>&1; then
                log_success "✓ MySQL remote access working"
            else
                log_warning "⚠ MySQL remote access test failed (may be normal for some configurations)"
            fi
        fi
    else
        log_error "✗ MySQL connection failed with provided credentials"
        verification_failed=1
    fi
    
    # Test PHP-FPM
    log_info "Testing PHP-FPM..."
    if systemctl is-active --quiet php${PHP_VERSION}-fpm && systemctl is-enabled --quiet php${PHP_VERSION}-fpm; then
        log_success "✓ PHP-FPM is running and enabled"
        
        # Test PHP configuration
        if php${PHP_VERSION} -v >/dev/null 2>&1; then
            log_success "✓ PHP ${PHP_VERSION} CLI working"
            
            # Test max_file_uploads setting
            current_max_uploads=$(php${PHP_VERSION} -r "echo ini_get('max_file_uploads');")
            if [ "$current_max_uploads" = "50" ]; then
                log_success "✓ max_file_uploads set to 50"
            else
                log_warning "⚠ max_file_uploads is $current_max_uploads (expected: 50)"
            fi
        else
            log_error "✗ PHP CLI verification failed"
            verification_failed=1
        fi
    else
        log_error "✗ PHP-FPM verification failed"
        verification_failed=1
    fi
    
    # Test Redis
    log_info "Testing Redis..."
    if systemctl is-active --quiet redis-server && systemctl is-enabled --quiet redis-server; then
        log_success "✓ Redis is running and enabled"
        
        # Test Redis with password
        if redis-cli -a "$REDIS_PASSWORD" ping >/dev/null 2>&1; then
            log_success "✓ Redis authentication working"
        else
            log_error "✗ Redis authentication failed"
            verification_failed=1
        fi
    else
        log_error "✗ Redis verification failed"
        verification_failed=1
    fi
    
    # Test Node.js
    log_info "Testing Node.js..."
    if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
        node_version=$(node -v)
        npm_version=$(npm -v)
        log_success "✓ Node.js $node_version and npm $npm_version working"
    else
        log_error "✗ Node.js/npm verification failed"
        verification_failed=1
    fi
    
    # Test Composer
    log_info "Testing Composer..."
    if command -v composer >/dev/null 2>&1; then
        composer_version=$(composer --version | head -n1)
        log_success "✓ Composer working: $composer_version"
    else
        log_error "✗ Composer verification failed"
        verification_failed=1
    fi
    
    # Test PM2
    log_info "Testing PM2..."
    if command -v pm2 >/dev/null 2>&1; then
        pm2_version=$(pm2 -v)
        log_success "✓ PM2 working: $pm2_version"
    else
        log_error "✗ PM2 verification failed"
        verification_failed=1
    fi
    
    # Test Deployer User
    log_info "Testing Deployer user..."
    if id "$DEPLOYER_USERNAME" >/dev/null 2>&1; then
        log_success "✓ Deployer user '$DEPLOYER_USERNAME' exists"
        
        # Test SSH directory
        if [ -d "/home/$DEPLOYER_USERNAME/.ssh" ]; then
            log_success "✓ SSH directory exists for deployer user"
            
            # Test SSH keys
            if [ -f "/home/$DEPLOYER_USERNAME/.ssh/id_rsa" ] && [ -f "/home/$DEPLOYER_USERNAME/.ssh/id_rsa.pub" ]; then
                log_success "✓ SSH key pair generated for deployer user"
            else
                log_warning "⚠ SSH keys missing for deployer user"
            fi
        else
            log_error "✗ SSH directory missing for deployer user"
            verification_failed=1
        fi
    else
        log_error "✗ Deployer user verification failed"
        verification_failed=1
    fi
    
    # Test Firewall
    log_info "Testing UFW Firewall..."
    if systemctl is-active --quiet ufw; then
        log_success "✓ UFW Firewall is active"
        
        # Check essential ports
        if ufw status | grep -q "22.*ALLOW"; then
            log_success "✓ SSH port (22) allowed"
        else
            log_error "✗ SSH port not allowed in firewall"
            verification_failed=1
        fi
        
        if ufw status | grep -q "80.*ALLOW"; then
            log_success "✓ HTTP port (80) allowed"
        else
            log_error "✗ HTTP port not allowed in firewall"
            verification_failed=1
        fi
        
        if ufw status | grep -q "443.*ALLOW"; then
            log_success "✓ HTTPS port (443) allowed"
        else
            log_error "✗ HTTPS port not allowed in firewall"
            verification_failed=1
        fi
    else
        log_error "✗ UFW Firewall not active"
        verification_failed=1
    fi
    
    # Test Fail2Ban
    log_info "Testing Fail2Ban..."
    if systemctl is-active --quiet fail2ban && systemctl is-enabled --quiet fail2ban; then
        log_success "✓ Fail2Ban is running and enabled"
    else
        log_error "✗ Fail2Ban verification failed"
        verification_failed=1
    fi
    
    # Test web directory permissions
    log_info "Testing web directory permissions..."
    if [ -d "/var/www/html" ]; then
        owner=$(stat -c "%U:%G" /var/www/html)
        permissions=$(stat -c "%a" /var/www/html)
        if [ "$owner" = "$DEPLOYER_USERNAME:www-data" ] && [ "$permissions" = "775" ]; then
            log_success "✓ Web directory permissions correct"
        else
            log_warning "⚠ Web directory permissions: $owner ($permissions) - may need adjustment"
        fi
    else
        log_error "✗ Web directory missing"
        verification_failed=1
    fi
    
    # Create test PHP file to verify web stack
    log_info "Testing web stack with PHP info..."
    test_php_file="/var/www/html/test_installation.php"
    echo "<?php phpinfo(); ?>" | sudo tee "$test_php_file" >/dev/null
    sudo chown "$DEPLOYER_USERNAME:www-data" "$test_php_file"
    
    # Debug: Check if file exists and has correct permissions
    if [ -f "$test_php_file" ]; then
        log_info "Test PHP file created successfully"
        file_perms=$(stat -c "%a" "$test_php_file")
        file_owner=$(stat -c "%U:%G" "$test_php_file")
        log_info "Test file permissions: $file_perms, owner: $file_owner"
    else
        log_error "Failed to create test PHP file"
        verification_failed=1
    fi
    
    # Debug: Test Nginx status
    if ! systemctl is-active --quiet nginx; then
        log_error "Nginx is not running - attempting restart"
        sudo systemctl restart nginx
        sleep 2
    fi
    
    # Debug: Test PHP-FPM status
    if ! systemctl is-active --quiet php${PHP_VERSION}-fpm; then
        log_error "PHP-FPM is not running - attempting restart"
        sudo systemctl restart php${PHP_VERSION}-fpm
        sleep 2
    fi
    
    # Test with curl - with detailed error reporting
    log_info "Testing HTTP response..."
    http_response=$(curl -s -w "HTTP_CODE:%{http_code}" "http://localhost/test_installation.php")
    http_code=$(echo "$http_response" | grep -o "HTTP_CODE:[0-9]*" | cut -d: -f2)
    response_body=$(echo "$http_response" | sed 's/HTTP_CODE:[0-9]*$//')
    
    log_info "HTTP Response Code: $http_code"
    
    if [ "$http_code" = "200" ] && echo "$response_body" | grep -q "PHP Version"; then
        log_success "✓ Web stack (Nginx + PHP-FPM) working"
        sudo rm -f "$test_php_file"
    else
        log_error "✗ Web stack test failed"
        log_error "HTTP Code: $http_code"
        log_error "Response preview: $(echo "$response_body" | head -5)"
        
        # Additional debugging
        log_info "Nginx error log (last 5 lines):"
        sudo tail -5 /var/log/nginx/error.log 2>/dev/null || log_warning "Cannot read Nginx error log"
        
        log_info "PHP-FPM error log (last 5 lines):"
        sudo tail -5 /var/log/php${PHP_VERSION}-fpm.log 2>/dev/null || log_warning "Cannot read PHP-FPM log"
        
        verification_failed=1
        sudo rm -f "$test_php_file"
    fi
    
    log_info "============================================"
    
    if [ $verification_failed -eq 0 ]; then
        log_success "🎉 INSTALLATION VERIFICATION - 100% SUCCESSFUL!"
        log_success "All components are working correctly!"
        return 0
    else
        log_error "❌ INSTALLATION VERIFICATION FAILED!"
        log_error "Some components are not working properly."
        log_error "Please check the errors above and fix them."
        return 1
    fi
}

#==============================================================================
# MAIN INSTALLATION FUNCTION
#==============================================================================

main() {
    log_info "Starting LEMP Stack Installation..."
    log_info "============================================"
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then 
        log_error "Please run as root (use sudo)"
        exit 1
    fi
    
    # Display configuration
    log_info "Configuration:"
    log_info "  - MySQL Version: $PHP_VERSION"
    log_info "  - Node.js Version: $NODE_MAJOR"
    log_info "  - Deployer User: $DEPLOYER_USERNAME"
    log_info "  - Timezone: $TIMEZONE"
    
    if [ "$MYSQL_ALLOW_REMOTE" = "any" ]; then
        log_warning "  - ⚠️  MySQL Remote Access: OPEN TO ALL IPs (SECURITY RISK!)"
    elif [ -n "$MYSQL_ALLOW_REMOTE" ]; then
        log_info "  - MySQL Remote Access: Specific IPs only ($MYSQL_ALLOW_REMOTE)"
    else
        log_info "  - MySQL Remote Access: Localhost only (Secure)"
    fi
    
    log_info "============================================"
    
    # Run installation steps
    update_system
    configure_firewall
    install_utilities
    install_mysql
    install_nginx
    install_php
    setup_deployer_user
    install_composer
    install_nodejs
    install_pm2
    install_redis
    install_fail2ban
    
    # Save credentials
    save_credentials
    
    # Final restart of services
    log_info "Restarting all services..."
    sudo systemctl restart nginx
    sudo systemctl restart php${PHP_VERSION}-fpm
    sudo systemctl restart mysql
    sudo systemctl restart redis-server
    
    # Run comprehensive verification
    log_info "Running installation verification..."
    if verify_installation; then
        log_success "Installation completed and verified successfully!"
    else
        log_error "Installation completed but verification failed!"
        log_error "Please address the issues above."
        exit 1
    fi
    
    log_success "============================================"
    log_success "============================================"
    log_success "LEMP Stack Installation Completed!"
    log_success "============================================"
    log_info ""
    log_info "IMPORTANT NEXT STEPS:"
    log_info "1. Review credentials in: /root/lemp_credentials.txt"
    log_info "2. Delete credentials file after saving: rm /root/lemp_credentials.txt"
    
    if [ "$MYSQL_ALLOW_REMOTE" = "any" ]; then
        log_warning ""
        log_warning "⚠️  SECURITY WARNING - MySQL Remote Access Enabled!"
        log_warning "⚠️  Root can login from ANY IP with password: $MYSQL_ROOT_PASSWORD"
        log_warning "⚠️  Test remote connection: mysql -u root -p -h $(hostname -I | awk '{print $1}')"
        log_warning "⚠️  Strongly consider restricting to specific IPs later!"
        log_warning ""
    fi
    
    log_info "3. Test SSH login: ssh $DEPLOYER_USERNAME@$(hostname -I | awk '{print $1}')"
    log_info "4. Verify installations as deployer:"
    log_info "   su - $DEPLOYER_USERNAME"
    log_info "   node -v && npm -v && composer --version && pm2 status"
    log_info "5. Check firewall: sudo ufw status"
    log_info "6. Configure Nginx virtual hosts in /etc/nginx/sites-available/"
    log_info ""
    log_info "Server IP: $(hostname -I | awk '{print $1}')"
    log_info ""
    log_info "============================================"
    log_info "DEPLOYER SSH PUBLIC KEY (for Git, etc.):"
    log_info "============================================"
    if [ -f "/home/$DEPLOYER_USERNAME/.ssh/id_rsa.pub" ]; then
        cat /home/$DEPLOYER_USERNAME/.ssh/id_rsa.pub
    else
        log_warning "SSH key not found at /home/$DEPLOYER_USERNAME/.ssh/id_rsa.pub"
    fi
    log_info "============================================"
}

# Run main function
main

exit 0