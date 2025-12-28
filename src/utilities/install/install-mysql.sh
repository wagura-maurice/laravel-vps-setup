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

log_section "MySQL Installation"

# Default configuration values
readonly MYSQL_VERSION="8.0"
readonly PACKAGE_MANAGER="apt-get"
readonly INSTALL_OPTS="-y --no-install-recommends"

# Required packages
readonly MYSQL_PACKAGES=(
    "mysql-server"
    "mysql-client"
    "default-libmysqlclient-dev"
)

# Function to install MySQL packages
install_mysql_packages() {
    log_info "Installing MySQL packages..."

    if ! DEBIAN_FRONTEND=noninteractive ${PACKAGE_MANAGER} install ${INSTALL_OPTS} "${MYSQL_PACKAGES[@]}"; then
        log_error "Failed to install MySQL packages"
        return 1
    fi

    log_success "MySQL packages installed successfully"
    return 0
}

# Function to configure MySQL for Laravel
configure_mysql_for_laravel() {
    log_info "Configuring MySQL for Laravel..."

    # Create custom configuration
    cat > /etc/mysql/mysql.conf.d/laravel.cnf <<-EOF
# Laravel MySQL Configuration
# Managed by Laravel setup script - DO NOT EDIT MANUALLY

[mysqld]
# General settings
user                    = mysql
pid-file                = /var/run/mysqld/mysqld.pid
socket                  = /var/run/mysqld/mysqld.sock
port                    = 3306
basedir                 = /usr
datadir                 = /var/lib/mysql
tmpdir                  = /tmp
lc-messages-dir         = /usr/share/mysql

# Connection and Threads
max_connections         = 200
max_connect_errors      = 1000
connect_timeout         = 30
wait_timeout            = 300
interactive_timeout     = 300
max_allowed_packet      = 256M
thread_cache_size       = 128
thread_handling         = pool-of-threads
thread_pool_size        = 16
thread_pool_max_threads = 1000

# Table and Buffer Settings
table_open_cache        = 4000
table_definition_cache  = 2000
table_open_cache_instances = 16
table_open_cache_size   = 2000

# InnoDB Settings
innodb_buffer_pool_size            = 1G
innodb_buffer_pool_instances       = 8
innodb_flush_log_at_trx_commit     = 1
innodb_log_buffer_size             = 16M
innodb_log_file_size               = 512M
innodb_log_files_in_group          = 2
innodb_file_per_table              = 1
innodb_autoinc_lock_mode           = 2
innodb_flush_method                = O_DIRECT
innodb_read_io_threads             = 8
innodb_write_io_threads            = 8
innodb_io_capacity                 = 2000
innodb_io_capacity_max             = 4000
innodb_lru_scan_depth              = 100
innodb_purge_threads               = 4
innodb_read_ahead_threshold        = 0
innodb_stats_on_metadata           = 0
innodb_use_native_aio              = 1
innodb_lock_wait_timeout           = 120
innodb_rollback_on_timeout         = 1
innodb_print_all_deadlocks         = 1
innodb_compression_level           = 6
innodb_compression_failure_threshold_pct = 5
innodb_compression_pad_pct_max     = 50

# MyISAM Settings (minimal as we use InnoDB)
key_buffer_size         = 16M
myisam_recover_options  = OFF

# Logging
slow_query_log_file     = /var/log/mysql/mysql-slow.log
slow_query_log          = 1
long_query_time         = 2
log_warnings            = 2
log_error               = /var/log/mysql/error.log

# Binary Logging (for replication)
server_id               = 1
log_bin                 = /var/log/mysql/mysql-bin
log_bin_index           = /var/log/mysql/mysql-bin.index
expire_logs_days        = 7
sync_binlog             = 1
binlog_format           = ROW
binlog_row_image        = FULL
binlog_cache_size       = 1M
max_binlog_size         = 100M
binlog_group_commit_sync_delay = 100

# Replication
read_only               = 0
skip_slave_start        = 1
slave_parallel_mode     = optimistic
slave_parallel_threads  = 4

# Security
local_infile            = 0
skip_name_resolve       = 1
secure_file_priv        = /var/lib/mysql-files

# Performance Schema
performance_schema                = ON
performance_schema_events_waits_history_long_size = 10000
performance_schema_events_waits_history_size = 10
performance_schema_max_table_instances = 50
performance_schema_max_thread_instances = 1000

# Other Settings
tmp_table_size          = 64M
max_heap_table_size     = 64M
join_buffer_size        = 2M
sort_buffer_size        = 2M
read_buffer_size        = 2M
read_rnd_buffer_size    = 4M
net_buffer_length       = 8K
myisam_sort_buffer_size = 64M

# Character Set
character-set-server    = utf8mb4
collation-server        = utf8mb4_unicode_ci
character-set-client-handshake = FALSE
init_connect           = 'SET NAMES utf8mb4'

# Laravel specific optimizations
innodb_read_only_compressed = OFF
innodb_adaptive_hash_index = ON
innodb_adaptive_flushing = ON
innodb_flush_neighbors = 1
innodb_random_read_ahead = ON
innodb_io_capacity = 2000
innodb_io_capacity_max = 4000
innodb_lru_scan_depth = 100
innodb_checksum_algorithm = crc32
innodb_checksum_algorithm = strict_crc32
innodb_lock_wait_timeout = 50
innodb_rollback_on_timeout = 1
innodb_print_all_deadlocks = 1
innodb_file_format = Barracuda
innodb_file_per_table = 1
innodb_large_prefix = 1
innodb_purge_threads = 4
innodb_read_ahead_threshold = 0
innodb_stats_on_metadata = 0
innodb_use_native_aio = 1
innodb_compression_level = 6
innodb_compression_failure_threshold_pct = 5
innodb_compression_pad_pct_max = 50
innodb_buffer_pool_dump_at_shutdown = 1
innodb_buffer_pool_load_at_startup = 1
innodb_buffer_pool_dump_pct = 40
innodb_buffer_pool_load_abort = 0
innodb_buffer_pool_load_now = 0
innodb_buffer_pool_filename = ib_buffer_pool
innodb_flush_neighbors = 1
innodb_flush_sync = 1
innodb_flushing_avg_loops = 30
innodb_max_dirty_pages_pct = 90
innodb_max_dirty_pages_pct_lwm = 10
innodb_adaptive_flushing = 1
innodb_adaptive_flushing_lwm = 10
innodb_adaptive_hash_index = 1
innodb_adaptive_hash_index_parts = 8
innodb_adaptive_max_sleep_delay = 15000
innodb_change_buffer_max_size = 25
innodb_change_buffering = all
innodb_checksum_algorithm = crc32
innodb_cmp_per_index_enabled = 0
innodb_commit_concurrency = 0
innodb_compression_failure_threshold_pct = 5
innodb_compression_level = 6
innodb_compression_pad_pct_max = 50
innodb_concurrency_tickets = 5000
innodb_deadlock_detect = 1
innodb_default_row_format = dynamic
innodb_disable_sort_file_cache = 0
innodb_fast_shutdown = 1
innodb_fill_factor = 100
innodb_flush_log_at_timeout = 1
innodb_flush_neighbors = 1
innodb_flush_sync = 1
innodb_ft_cache_size = 8000000
innodb_ft_min_token_size = 3
innodb_ft_server_stopword_table =
innodb_io_capacity = 2000
innodb_io_capacity_max = 4000
innodb_lock_wait_timeout = 50
innodb_log_buffer_size = 16M
innodb_log_compressed_pages = 1
innodb_log_file_size = 1G
innodb_lru_scan_depth = 1000
innodb_max_dirty_pages_pct = 90
innodb_max_purge_lag = 0
innodb_max_purge_lag_delay = 0
innodb_old_blocks_pct = 37
innodb_old_blocks_time = 1000
innodb_online_alter_log_max_size = 1G
innodb_open_files = 4000
innodb_page_cleaners = 4
innodb_print_all_deadlocks = 1
innodb_purge_batch_size = 30
innodb_purge_threads = 4
innodb_random_read_ahead = 0
innodb_read_ahead_threshold = 56
innodb_read_io_threads = 8
innodb_read_only = 0
innodb_rollback_on_timeout = 1
innodb_sort_buffer_size = 1M
innodb_spin_wait_delay = 6
innodb_stats_auto_recalc = 1
innodb_stats_include_delete_marked = 0
innodb_stats_method = nulls_unequal
innodb_stats_on_metadata = 0
innodb_stats_persistent = 1
innodb_stats_persistent_sample_pages = 20
innodb_stats_transient_sample_pages = 8
innodb_status_output = 0
innodb_status_output_locks = 0
innodb_strict_mode = 1
innodb_sync_array_size = 1
innodb_sync_spin_loops = 30
innodb_table_locks = 1
innodb_thread_concurrency = 0
innodb_thread_sleep_delay = 100
innodb_use_native_aio = 1
innodb_write_io_threads = 8

# Performance Schema
performance_schema = ON
performance_schema_events_waits_history_long_size = 10000
performance_schema_events_waits_history_size = 10
performance_schema_max_table_instances = 500
performance_schema_max_thread_instances = 1000

# Logging
slow_query_log_file = /var/log/mysql-slow.log
slow_query_log = 1
long_query_time = 2
log_slow_verbosity = query_plan
log_warnings = 2
log_error = /var/log/mysql/error.log

# Binary Logging (for replication)
server_id = 1
log_bin = /var/log/mysql/mysql-bin
log_bin_index = /var/log/mysql/mysql-bin.index
expire_logs_days = 7
sync_binlog = 1
binlog_format = ROW
binlog_row_image = FULL
binlog_cache_size = 1M
max_binlog_size = 100M
binlog_group_commit_sync_delay = 100

# Replication
read_only = 0
skip_slave_start = 1
slave_parallel_mode = optimistic
slave_parallel_threads = 4

# Security
local_infile = 0
skip_name_resolve = 1
secure_file_priv = /var/lib/mysql-files

# Other Settings
tmp_table_size = 64M
max_heap_table_size = 64M
join_buffer_size = 2M
sort_buffer_size = 2M
read_buffer_size = 2M
read_rnd_buffer_size = 4M
net_buffer_length = 8K
myisam_sort_buffer_size = 64M

# Character Set
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
character-set-client-handshake = FALSE
init_connect = 'SET NAMES utf8mb4'
EOF

    # Set proper permissions
    chown -R mysql:mysql /etc/mysql/
    chmod 644 /etc/mysql/mysql.conf.d/laravel.cnf

    # Create log directory if it doesn't exist
    mkdir -p /var/log/mysql
    chown -R mysql:mysql /var/log/mysql

    log_info "MySQL configuration created at /etc/mysql/mysql.conf.d/laravel.cnf"
    return 0
}

# Function to secure MySQL installation
secure_mysql() {
    log_info "Securing MySQL installation..."

    # Use hardcoded root password as specified
    local root_password="Rtcv39$$"

    # Create a temporary file with SQL commands
    local temp_sql=$(mktemp)

    cat > "${temp_sql}" <<-EOF
-- Remove anonymous users
DELETE FROM mysql.user WHERE User='';
-- Remove test database
DROP DATABASE IF EXISTS test;
-- Remove test database access
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
-- Reload privileges
FLUSH PRIVILEGES;
-- Set root password for localhost
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '${root_password}';
-- Create root user for remote access if it doesn't exist
CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED WITH mysql_native_password BY '${root_password}';
-- Grant all privileges to root@% for remote access
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
-- Remove any empty user
DELETE FROM mysql.user WHERE User='';
-- Remove any empty database
DELETE FROM mysql.db WHERE Db='';
-- Reload privileges
FLUSH PRIVILEGES;
EOF

    # Execute SQL commands
    if ! mysql -u root < "${temp_sql}"; then
        log_warning "Failed to secure MySQL installation. Attempting to continue..."
    fi

    # Clean up
    rm -f "${temp_sql}"

    # Save root password to a secure location
    local root_credentials="/root/.my.cnf"
    cat > "${root_credentials}" <<-EOF
[client]
user=root
password='${root_password}'
host=localhost
EOF

    # Secure the credentials file
    chmod 600 "${root_credentials}"

    log_info "MySQL installation secured successfully"
    log_info "Root password: ${root_password}"
    log_info "Root user configured for remote access (root@%)"
    log_warning "Root password saved to ${root_credentials}. Keep this file secure!"
    return 0
}

    # Function to create Laravel database
    create_laravel_db() {
        log_info "Creating Laravel database..."

        # Ensure environment is loaded
        load_environment

        # Use hardcoded root password
        local root_password="Rtcv39$$"
        
        # Use database name from environment or default
        local db_name="${DB_NAME:-laravel_db}"
        
        # Create database if it doesn't exist
        mysql -u root -p"${root_password}" -e "CREATE DATABASE IF NOT EXISTS \`${db_name}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>/dev/null || {
            log_warning "Database may already exist, continuing..."
        }
        
        mysql -u root -p"${root_password}" -e "FLUSH PRIVILEGES;"

        # Save credentials to a secure file (using root user)
        local db_credentials="/root/.laravel_db_credentials"
        cat > "${db_credentials}" <<-EOF
[client]
user=root
password='${root_password}'
host=localhost
database=${db_name}
EOF

        chmod 600 "${db_credentials}"

        log_success "Laravel database created successfully"
        log_info "Database: ${db_name}"
        log_info "Using root user for database access (remote access enabled)"
        log_warning "Root password: ${root_password} - Keep this secure!"
        return 0
    }

# Function to restart MySQL
restart_mysql() {
    log_info "Restarting MySQL service..."

    if ! systemctl restart mysql; then
        log_error "Failed to restart MySQL service"
        journalctl -u mysql --no-pager -n 50
        return 1
    fi

    # Wait for MySQL to start
    local max_attempts=30
    local attempt=1

    while ! mysql -e "SELECT 1" >/dev/null 2>&1; do
        if [ ${attempt} -ge ${max_attempts} ]; then
            log_error "MySQL failed to start after ${max_attempts} attempts"
            return 1
        fi

        log_info "Waiting for MySQL to start (attempt ${attempt}/${max_attempts})..."
        sleep 1
        attempt=$((attempt + 1))
    done

    log_info "MySQL service restarted successfully"
    return 0
}

# Main installation function
install_mysql() {
    local success=true

    log_info "Starting MySQL ${MYSQL_VERSION} installation..."

    # Install MySQL packages
    if ! install_mysql_packages; then
        success=false
    fi

    # Configure MySQL
    if ! configure_mysql_for_laravel; then
        success=false
    fi

    # Restart MySQL to apply configuration
    if ! restart_mysql; then
        success=false
    fi

    # Secure MySQL installation
    if ! secure_mysql; then
        success=false
    fi

    # Create Laravel database and user
    if ! create_laravel_db; then
        success=false
    fi

    # Final status
    if [ "${success}" = true ]; then
        log_success "MySQL ${MYSQL_VERSION} installation completed successfully"
        log_info "Run the configuration script to set up additional settings if needed:"
        log_info "  ./src/utilities/configure/configure-mysql.sh"
        return 0
    else
        log_error "MySQL installation completed with errors"
        return 1
    fi
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi

    install_mysql
    exit $?
fi