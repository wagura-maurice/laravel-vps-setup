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

log_section "PHP and Nginx Installation"

# Function to install Nginx
install_nginx() {
    log_info "Installing Nginx..."

    # Install Nginx
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

# Function to install PHP 8.4 with Laravel required extensions
install_php() {
    log_info "Installing PHP 8.4 and required extensions..."

    # Add PHP repository
    add-apt-repository ppa:ondrej/php -y
    apt-get update

    # Install PHP 8.4 and Laravel-required extensions
    local php_packages=(
        "php8.4"
        "php8.4-fpm"
        "php8.4-cli"
        "php8.4-common"
        "php8.4-curl"
        "php8.4-mbstring"
        "php8.4-gd"
        "php8.4-xml"
        "php8.4-zip"
        "php8.4-bcmath"
        "php8.4-intl"
        "php8.4-mysql"
        "php8.4-readline"
        "php8.4-imagick"
        "php8.4-gmp"
        "php8.4-soap"
        "php8.4-ldap"
        "php8.4-msgpack"
        "php8.4-igbinary"
        "php8.4-redis"
        "php8.4-swoole"
        "php8.4-apcu"
        "php8.4-opcache"
    )

    if ! DEBIAN_FRONTEND=noninteractive apt-get install -y "${php_packages[@]}"; then
        log_error "Failed to install PHP packages"
        return 1
    fi

    log_success "PHP 8.4 and extensions installed"
    return 0
}

# Function to configure PHP for Laravel
configure_php() {
    log_info "Configuring PHP for Laravel..."

    # Configure PHP-FPM for Laravel with Africa/Nairobi timezone
    cat > /etc/php/8.4/fpm/php.ini <<EOL
[PHP]
engine = On
short_open_tag = Off
precision = 14
output_buffering = 4096
zlib.output_compression = Off
implicit_flush = Off
serialize_precision = -1
disable_functions = 
disable_classes = 
zend.enable_gc = On
expose_php = Off
max_execution_time = 600
max_input_time = 1200
memory_limit = 256M
error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT
display_errors = Off
display_startup_errors = Off
log_errors = On
error_log = /var/log/php8.4-fpm.log
log_errors_max_len = 1024
ignore_repeated_errors = Off
ignore_repeated_source = Off
report_memleaks = On
html_errors = Off
variables_order = "GPCS"
request_order = "GP"
register_argc_argv = Off
auto_globals_jit = On
post_max_size = 100M
auto_prepend_file = 
auto_append_file = 
default_mimetype = "text/html"
default_charset = "UTF-8"
doc_root = 
user_dir = 
enable_dl = Off
file_uploads = On
upload_max_filesize = 10M
max_file_uploads = 20
allow_url_fopen = On
allow_url_include = Off
default_socket_timeout = 60

[CLI Server]
cli_server.color = On

[Date]
date.timezone = Africa/Nairobi

[filter]
[iconv]
[imap]
[intl]
[sqlite3]
[Pcre]
pcre.jit = 1

[MySQLi]
mysqli.max_persistent = -1
mysqli.allow_persistent = On
mysqli.max_links = -1
mysqli.cache_size = 2000
mysqli.default_port = 3306
mysqli.default_socket = 
mysqli.default_host = 
mysqli.default_user = 
mysqli.default_pw = 
mysqli.reconnect = Off

[mysqlnd]
mysqlnd.collect_statistics = On
mysqlnd.collect_memory_statistics = Off

[OCI8]

[PostgreSQL]
pgsql.allow_persistent = On
pgsql.auto_reset_persistent = Off
pgsql.max_persistent = -1
pgsql.max_links = -1
pgsql.ignore_notice = 0
pgsql.log_notice = 0

[bcmath]
bcmath.scale = 0

[Session]
session.save_handler = files
session.save_path = "/var/lib/php/sessions"
session.use_strict_mode = 0
session.use_cookies = 1
session.use_only_cookies = 1
session.name = PHPSESSID
session.auto_start = 0
session.cookie_lifetime = 0
session.cookie_path = /
session.cookie_domain = 
session.cookie_httponly = 1
session.cookie_samesite = Lax
session.serialize_handler = php
session.gc_probability = 1
session.gc_divisor = 100
session.gc_maxlifetime = 140
session.referer_check = 
session.cache_limiter = nocache
session.cache_expire = 180
session.use_trans_sid = 0
session.sid_length = 26
session.trans_sid_tags = "a=href,area=href,frame=src,form="
session.sid_bits_per_character = 5

[Assertion]
zend.assertions = -1

[COM]

[mbstring]
mbstring.language = neutral
mbstring.internal_encoding = UTF-8
mbstring.http_input = UTF-8
mbstring.http_output = UTF-8
mbstring.encoding_translation = 0
mbstring.detect_order = auto
mbstring.substitute_character = none
mbstring.func_overload = 0

[gd]
[exif]
[sysvshm]
[opcache]
opcache.enable=1
opcache.enable_cli=1
opcache.memory_consumption=256
opcache.interned_strings_buffer=12
opcache.max_accelerated_files=1000
opcache.validate_timestamps=0
opcache.save_comments=1
opcache.fast_shutdown=1
opcache.huge_code_pages=1

[curl]
[openssl]
EOL

    # Configure CLI PHP settings with Africa/Nairobi timezone
    cat > /etc/php/8.4/cli/php.ini <<EOL
[PHP]
engine = On
short_open_tag = Off
precision = 14
output_buffering = 4096
zlib.output_compression = Off
implicit_flush = Off
serialize_precision = -1
disable_functions = 
disable_classes = 
zend.enable_gc = On
expose_php = Off
max_execution_time = 0
max_input_time = 120
memory_limit = 1G
error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT
display_errors = Off
display_startup_errors = Off
log_errors = On
error_log = /var/log/php_errors.log
log_errors_max_len = 1024
ignore_repeated_errors = Off
ignore_repeated_source = Off
report_memleaks = On
html_errors = Off
variables_order = "GPCS"
request_order = "GP"
register_argc_argv = Off
auto_globals_jit = On
post_max_size = 100M
auto_prepend_file = 
auto_append_file = 
default_mimetype = "text/html"
default_charset = "UTF-8"
doc_root = 
user_dir = 
enable_dl = Off
file_uploads = On
upload_max_filesize = 10M
max_file_uploads = 20
allow_url_fopen = On
allow_url_include = Off
default_socket_timeout = 60

[CLI Server]
cli_server.color = On

[Date]
date.timezone = Africa/Nairobi

[filter]
[iconv]
[imap]
[intl]
[sqlite3]
[Pcre]
pcre.jit = 1

[MySQLi]
mysqli.max_persistent = -1
mysqli.allow_persistent = On
mysqli.max_links = -1
mysqli.cache_size = 200
mysqli.default_port = 3306
mysqli.default_socket = 
mysqli.default_host = 
mysqli.default_user = 
mysqli.default_pw = 
mysqli.reconnect = Off

[mysqlnd]
mysqlnd.collect_statistics = On
mysqlnd.collect_memory_statistics = Off

[OCI8]

[PostgreSQL]
pgsql.allow_persistent = On
pgsql.auto_reset_persistent = Off
pgsql.max_persistent = -1
pgsql.max_links = -1
pgsql.ignore_notice = 0
pgsql.log_notice = 0

[bcmath]
bcmath.scale = 0

[Session]
session.save_handler = files
session.save_path = "/var/lib/php/sessions"
session.use_strict_mode = 0
session.use_cookies = 1
session.use_only_cookies = 1
session.name = PHPSESSID
session.auto_start = 0
session.cookie_lifetime = 0
session.cookie_path = /
session.cookie_domain = 
session.cookie_httponly = 1
session.cookie_samesite = Lax
session.serialize_handler = php
session.gc_probability = 1
session.gc_divisor = 100
session.gc_maxlifetime = 1440
session.referer_check = 
session.cache_limiter = nocache
session.cache_expire = 180
session.use_trans_sid = 0
session.sid_length = 26
session.trans_sid_tags = "a=href,area=href,frame=src,form="
session.sid_bits_per_character = 5

[Assertion]
zend.assertions = -1

[COM]

[mbstring]
mbstring.language = neutral
mbstring.internal_encoding = UTF-8
mbstring.http_input = UTF-8
mbstring.http_output = UTF-8
mbstring.encoding_translation = 0
mbstring.detect_order = auto
mbstring.substitute_character = none
mbstring.func_overload = 0

[gd]
[exif]
[sysvshm]
[opcache]
opcache.enable=0
opcache.enable_cli=0

[curl]
[openssl]
EOL

    log_success "PHP configured for Laravel with Africa/Nairobi timezone"
    return 0
}

# Function to configure PHP-FPM pool
configure_php_fpm() {
    log_info "Configuring PHP-FPM pool..."

    # Configure PHP-FPM pool for Laravel
    cat > /etc/php/8.4/fpm/pool.d/www.conf <<EOL
; Start a new pool named 'www'
[www]
user = www-data
group = www-data
listen = /run/php/php8.4-fpm.sock
listen.owner = www-data
listen.group = www-data
listen.mode = 0600

; Set permissions for the Unix socket
listen.allowed_clients = 127.0.1

pm = dynamic
pm.max_children = 50
pm.start_servers = 5
pm.min_spare_servers = 5
pm.max_spare_servers = 35
pm.max_requests = 500

request_terminate_timeout = 300

; Common Variables
env[HOSTNAME] = \$HOSTNAME
env[PATH] = /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
env[TMP] = /tmp
env[TMPDIR] = /tmp
env[TEMP] = /tmp

; Catch workers output
catch_workers_output = yes
EOL

    # Restart PHP-FPM to apply changes
    systemctl restart php8.4-fpm
    systemctl enable php8.4-fpm

    log_success "PHP-FPM pool configured and restarted"
    return 0
}

# Function to install Node.js and NPM (version 22)
install_nodejs() {
    log_info "Installing Node.js version 22..."

    # Install NodeSource repository for Node.js 22
    curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
    apt-get install -y nodejs

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

    # Create deployer user with password Qwerty123!
    if ! id "deployer" &>/dev/null; then
        useradd -m -s /bin/bash -p $(openssl passwd -1 "Qwerty123!") deployer
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
    echo 'export PATH="$PATH:/usr/local/bin"' >> /home/deployer/.bashrc
    echo 'export COMPOSER_HOME="/home/deployer/.composer"' >> /home/deployer/.bashrc

    log_success "Deployer user created with sudo privileges and proper configuration"
    return 0
}

# Function to set up web directory
setup_web_directory() {
    log_info "Setting up web directory..."

    # Ensure /var/www/html exists
    mkdir -p /var/www/html

    # Set deployer user as owner of /var/www/html
    chown -R deployer:deployer /var/www/html
    chmod -R 755 /var/www/html

    # Ensure proper permissions for Laravel operations
    sudo -u deployer -H chmod -R 775 /var/www/html
    sudo -u deployer -H chmod -R 775 /var/www/html/storage
    sudo -u deployer -H chmod -R 775 /var/www/html/bootstrap/cache

    log_success "Web directory set up with deployer ownership"
    return 0
}

# Main installation function
install_php_main() {
    log_info "Starting PHP and Nginx installation..."

    local success=true

    if ! install_nginx; then
        log_error "Failed to install Nginx"
        success=false
    fi

    if ! install_php; then
        log_error "Failed to install PHP"
        success=false
    fi

    if ! configure_php; then
        log_error "Failed to configure PHP"
        success=false
    fi

    if ! configure_php_fpm; then
        log_error "Failed to configure PHP-FPM"
        success=false
    fi

    if ! install_nodejs; then
        log_error "Failed to install Node.js"
        success=false
    fi

    if ! create_deployer_user; then
        log_error "Failed to create deployer user"
        success=false
    fi

    if ! setup_web_directory; then
        log_error "Failed to set up web directory"
        success=false
    fi

    if [ "${success}" = true ]; then
        log_success "PHP and Nginx installation completed successfully!"
        log_info "Deployer user created with sudo privileges"
        log_info "Web directory set up with deployer ownership"
        return 0
    else
        log_error "PHP and Nginx installation completed with errors"
        return 1
    fi
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi

    install_php_main
    exit $?
fi
