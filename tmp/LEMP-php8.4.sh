#!/bin/bash

#==============================================================================
# LEMP Stack Installation Script (Ubuntu/Debian)
# Nginx + MySQL + PHP 8.4 + Node.js 22 + Redis + Deployer User Setup
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
    
    log_success "Nginx installed successfully"
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
    
    sudo apt install -y curl wget git unzip ca-certificates gnupg
    
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