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

log_section "Redis Configuration for Laravel"


# Function to configure Redis for Laravel
configure_redis_for_laravel() {
    log_info "Configuring Redis for Laravel..."
    
    # Ensure environment is loaded
    load_environment
    
    # Configure Redis for Laravel with environment variables
    cat > /etc/redis/redis.conf <<EOL
# Redis configuration file
# Managed by Laravel setup script - DO NOT EDIT MANUALLY

# Network
bind ${REDIS_HOST}
port ${REDIS_PORT}
timeout 0
tcp-keepalive 300

# General Settings
daemonize yes
supervised systemd
pidfile /var/run/redis/redis-server.pid
loglevel notice
logfile /var/log/redis/redis-server.log
databases 16
always-show-logo yes

# Snapshotting
save 900 1
save 300 10
save 60 10000
stop-writes-on-bgsave-error yes
rdbcompression yes
rdbchecksum yes
dbfilename dump.rdb
dir /var/lib/redis

# Replication
replica-serve-stale-data yes
replica-read-only yes
repl-diskless-sync no
repl-diskless-sync-delay 5
repl-disable-tcp-nodelay no
replica-priority 100

# Clients
maxclients 10000

# Memory Management
maxmemory 256mb
maxmemory-policy allkeys-lru
maxmemory-samples 5
lfu-log-factor 10
lfu-decay-time 1

# Append Only File
appendonly no
appendfilename "appendonly.aof"
appendfsync everysec
no-appendfsync-on-rewrite no
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 64mb
aof-load-truncated yes
aof-use-rdb-preamble yes

# Lua Scripting
lua-time-limit 5000

# Slow Log
slowlog-log-slower-than 10000
slowlog-max-len 128

# Latency Monitoring
latency-monitor-threshold 0

# Event Notification
notify-keyspace-events ""

# Advanced Configuration
hash-max-ziplist-entries 512
hash-max-ziplist-value 64
list-max-ziplist-size -2
list-compress-depth 0
set-max-intset-entries 512
zset-max-ziplist-entries 128
zset-max-ziplist-value 64
hll-sparse-max-bytes 3000
stream-node-max-bytes 4096
stream-node-max-entries 100

# Active Replication
activerewrite aof-enabled yes

# Client Output Buffer Limits
client-output-buffer-limit normal 0 0 0
client-output-buffer-limit replica 256mb 64mb 60
client-output-buffer-limit pubsub 32mb 8mb 60

# Internal Execution
hz 10
dynamic-hz yes
aof-rewrite-incremental-fsync yes
rdb-save-incremental-fsync yes

# Logging
syslog-enabled no
syslog-ident redis
syslog-facility local0

# Security (no password by default for localhost)
# requirepass
rename-command FLUSHDB ""
rename-command FLUSHALL ""
rename-command KEYS ""
EOL

    # Restart Redis to apply changes
    systemctl restart redis-server
    systemctl enable redis-server
    
    log_success "Redis configured for Laravel with environment settings"
    return 0
}

# Function to update Laravel's cache configuration
update_laravel_cache_config() {
    log_info "Updating Laravel's cache configuration for Redis..."
    
    # Ensure environment is loaded
    load_environment
    
    local project_name="${LARAVEL_PROJECT_NAME:-default_laravel_project}"
    local project_path="/var/www/html/${project_name}"
    
    # Check if Laravel project exists
    if [ ! -f "${project_path}/.env" ]; then
        log_warning "Laravel project not found at ${project_path}, skipping cache configuration"
        return 0
    fi
    
    # Update .env file with Redis settings
    sudo -u deployer -H bash -c "
        sed -i 's/REDIS_HOST=.*/REDIS_HOST=${REDIS_HOST:-localhost}/' ${project_path}/.env
        sed -i 's/REDIS_PASSWORD=.*/REDIS_PASSWORD=${REDIS_PASSWORD:-}/' ${project_path}/.env
        sed -i 's/REDIS_PORT=.*/REDIS_PORT=${REDIS_PORT:-6379}/' ${project_path}/.env
        sed -i 's/REDIS_DB=.*/REDIS_DB=0/' ${project_path}/.env
        sed -i 's/CACHE_DRIVER=.*/CACHE_DRIVER=redis/' ${project_path}/.env
        sed -i 's/SESSION_DRIVER=.*/SESSION_DRIVER=redis/' ${project_path}/.env
        sed -i 's/QUEUE_CONNECTION=.*/QUEUE_CONNECTION=redis/' ${project_path}/.env
    "
    
    # Clear and cache configuration
    sudo -u deployer -H bash -c "
        cd ${project_path}
        php artisan config:clear
        php artisan cache:clear
    "
    
    log_success "Laravel cache configuration updated for Redis"
    return 0
}

# Main configuration function
configure_redis_main() {
    log_info "Starting Redis configuration for Laravel..."
    
    local success=true
    
    # Configure Redis
    if ! configure_redis_for_laravel; then
        log_error "Failed to configure Redis for Laravel"
        success=false
    fi
    
    # Update Laravel cache configuration
    if ! update_laravel_cache_config; then
        log_error "Failed to update Laravel cache configuration"
        success=false
    fi
    
    if [ "${success}" = true ]; then
        log_success "Redis configuration for Laravel completed successfully!"
        return 0
    else
        log_error "Redis configuration completed with errors"
        return 1
    fi
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi

    configure_redis_main
    exit $?
fi