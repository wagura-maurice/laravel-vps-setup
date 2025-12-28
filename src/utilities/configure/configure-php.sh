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

log_section "PHP Configuration for Laravel"


# Function to configure PHP for Laravel
configure_php_for_laravel() {
    log_info "Configuring PHP for Laravel..."
    
    # Ensure environment is loaded
    load_environment
    
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
max_execution_time = ${PHP_MAX_EXECUTION_TIME}
max_input_time = 1200
memory_limit = ${PHP_MEMORY_LIMIT}
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
upload_max_filesize = ${PHP_UPLOAD_LIMIT}
max_file_uploads = 20
allow_url_fopen = On
allow_url_include = Off
default_socket_timeout = 60

[CLI Server]
cli_server.color = On

[Date]
date.timezone = ${TIMEZONE}

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
opcache.enable=1
opcache.enable_cli=1
opcache.memory_consumption=256
opcache.interned_strings_buffer=12
opcache.max_accelerated_files=10000
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
upload_max_filesize = ${PHP_UPLOAD_LIMIT}
max_file_uploads = 20
allow_url_fopen = On
allow_url_include = Off
default_socket_timeout = 60

[CLI Server]
cli_server.color = On

[Date]
date.timezone = ${TIMEZONE}

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

    log_success "PHP configured for Laravel with ${TIMEZONE} timezone"
    return 0
}

# Function to configure PHP-FPM pool for Laravel
configure_php_fpm_pool() {
    log_info "Configuring PHP-FPM pool for Laravel..."
    
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

# Main configuration function
configure_php_main() {
    log_info "Starting PHP configuration for Laravel..."
    
    local success=true
    
    # Configure PHP for Laravel
    if ! configure_php_for_laravel; then
        log_error "Failed to configure PHP for Laravel"
        success=false
    fi
    
    # Configure PHP-FPM pool
    if ! configure_php_fpm_pool; then
        log_error "Failed to configure PHP-FPM pool"
        success=false
    fi
    
    if [ "${success}" = true ]; then
        log_success "PHP configuration for Laravel completed successfully!"
        return 0
    else
        log_error "PHP configuration completed with errors"
        return 1
    fi
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi

    configure_php_main
    exit $?
fi
