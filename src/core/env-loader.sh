#!/bin/bash
set -euo pipefail

# Environment Loader for Laravel Setup and Management
# This script provides a unified way to load environment variables and configurations
# for both setup and management scripts.

# Prevent direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error: This script should be sourced, not executed directly" >&2
    echo "Usage: source $0" >&2
    exit 1
fi

# Main environment loading function

export ENV_LOADED=1

# Set script directory if not already set
if [ -z "${SCRIPT_DIR:-}" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

# Set project root relative to script directory (go up two levels from src/core/ to reach project root)
if [ -z "${PROJECT_ROOT:-}" ]; then
    PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../" && pwd)"
fi

# Verify PROJECT_ROOT is correct by checking for expected files/directories
if [ ! -d "${PROJECT_ROOT}/src" ] && [ ! -f "${PROJECT_ROOT}/.env" ] && [ ! -f "${PROJECT_ROOT}/laravel-setup-system.sh" ]; then
    # If not found, try alternative: maybe we're already at project root
    if [ -d "${SCRIPT_DIR}/../../src" ]; then
        PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../" && pwd)"
    else
        # Last resort: assume current directory is project root if src/ exists
        if [ -d "${SCRIPT_DIR}/../.." ] && [ -d "$(cd "${SCRIPT_DIR}/../.." && pwd)/src" ]; then
            PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
        fi
    fi
fi

# Set default directories
: "${SRC_DIR:=${PROJECT_ROOT}/src}"
: "${CORE_DIR:=${SRC_DIR}/core}"
: "${UTILS_DIR:=${SRC_DIR}/utilities}"
: "${LOG_DIR:=${PROJECT_ROOT}/logs}"
: "${CONFIG_DIR:=${PROJECT_ROOT}/config}"
: "${DATA_DIR:=${PROJECT_ROOT}/data}"
: "${ENV_FILE:=${PROJECT_ROOT}/.env}"
: "${SCRIPT_NAME:=${0##*/}}"
: "${LOG_LEVEL:="INFO"}"
: "${LOG_FILE:=${LOG_DIR}/laravel-setup-$(date +%Y%m%d%H%M%S).log}"

# Export all paths and variables
export PROJECT_ROOT SRC_DIR CORE_DIR UTILS_DIR LOG_DIR CONFIG_DIR DATA_DIR ENV_FILE LOG_LEVEL LOG_FILE

# Ensure required directories exist with proper permissions
mkdir -p "${LOG_DIR}" "${CONFIG_DIR}" "${DATA_DIR}" "${PROJECT_ROOT}/tmp" 2>/dev/null || {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] Failed to create required directories" >&2
    return 1
}

# Set proper permissions for directories
chmod 750 "${LOG_DIR}" "${CONFIG_DIR}" "${DATA_DIR}" "${PROJECT_ROOT}/tmp" 2>/dev/null || true

# Simple log function for early initialization
log() {
    if [ $# -ge 2 ]; then
        local level="$1"
        shift
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [${level}] $*" | tee -a "${LOG_FILE}" >&2
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [DEBUG] $*" | tee -a "${LOG_FILE}" >&2
    fi
}

# Source logging functions
if [ -f "${CORE_DIR}/logging.sh" ]; then
    # Source the logging functions
    if ! source "${CORE_DIR}/logging.sh"; then
        log "WARNING" "Failed to source logging.sh, using fallback logging"
    else
        # Initialize logging if init_logging exists
        if type -t init_logging >/dev/null 2>&1; then
            if ! init_logging; then
                log "WARNING" "Failed to initialize logging, using fallback"
            fi
        else
            log "WARNING" "init_logging function not found, using fallback logging"
        fi
    fi
else
    # Fallback logging if logging.sh doesn't exist
    log_info() { log "INFO" "$@"; }
    log_warning() { log "WARNING" "$@"; }
    log_error() { log "ERROR" "$@"; exit 1; }
    log_debug() { [ "${LOG_LEVEL}" = "DEBUG" ] && log "DEBUG" "$@"; }
    
    log_warning "Using fallback logging - logging.sh not found in ${CORE_DIR}"
fi

# Load common functions
if [ -f "${CORE_DIR}/common-functions.sh" ]; then
    source "${CORE_DIR}/common-functions.sh"
else
    log_error "common-functions.sh not found in ${CORE_DIR}" 1
fi

# Function to set default values for environment variables
set_defaults() {
    declare -gA DEFAULTS=(
        [PROJECT_ROOT]="${PROJECT_ROOT:-}"
        [SRC_DIR]="${SRC_DIR:-${PROJECT_ROOT}/src}"
        [CORE_DIR]="${CORE_DIR:-${PROJECT_ROOT}/src/core}"
        [LOG_DIR]="${LOG_DIR:-${PROJECT_ROOT}/logs}"
        [CONFIG_DIR]="${CONFIG_DIR:-${PROJECT_ROOT}/config}"
        [LARAVEL_DATA_DIR]="${LARAVEL_DATA_DIR:-/var/www/html/${LARAVEL_PROJECT_NAME:-laravel}/storage}"
        [DB_TYPE]="${DB_TYPE:-mysql}"
        [DB_HOST]="${DB_HOST:-localhost}"
        [DB_PORT]="${DB_PORT:-3306}"
        [DB_NAME]="${DB_NAME:-laravel_db}"
        [DB_USER]="${DB_USER:-root}"
        [DB_PASS]="${DB_PASS:-Rtcv39$$}"
        [PHP_MEMORY_LIMIT]="${PHP_MEMORY_LIMIT:-256M}"
        [PHP_UPLOAD_LIMIT]="${PHP_UPLOAD_LIMIT:-10M}"
        [PHP_MAX_EXECUTION_TIME]="${PHP_MAX_EXECUTION_TIME:-600}"
        [TIMEZONE]="${TIMEZONE:-Africa/Nairobi}"
        [DOMAIN_NAME]="${DOMAIN_NAME:-localhost}"
        [LARAVEL_PROJECT_NAME]="${LARAVEL_PROJECT_NAME:-default_laravel_project}"
        [REDIS_HOST]="${REDIS_HOST:-localhost}"
        [REDIS_PORT]="${REDIS_PORT:-6379}"
        [REDIS_PASSWORD]="${REDIS_PASSWORD:-}"
    )
}

# Load environment from .env file if it exists
if [ -f "${PROJECT_ROOT}/.env" ]; then
    # Source the .env file
    set -o allexport
    source "${PROJECT_ROOT}/.env"
    set +o allexport
    
    log_info "Loaded environment variables from ${PROJECT_ROOT}/.env"
else
    log_warning "No .env file found at ${PROJECT_ROOT}/.env, using default values"
fi

# Set default values
set_defaults

# Load environment from .env file
load_environment() {
    # Prevent multiple loads
    if [ -n "${ENV_LOADED:-}" ]; then
        return 0
    fi
    
    # Ensure PROJECT_ROOT is set
    if [ -z "${PROJECT_ROOT:-}" ]; then
        echo "Error: PROJECT_ROOT is not set" >&2
        return 1
    fi
    
    local env_file="${ENV_FILE:-${PROJECT_ROOT}/.env}"
    export ENV_FILE="$env_file"
    
    # Create required directories if they don't exist
    mkdir -p "$(dirname "$env_file")" 2>/dev/null || {
        log_error "Failed to create directory for .env file"
        return 1
    }
    
    # Create default .env if it doesn't exist
    if [[ ! -f "$env_file" ]]; then
        log_warning "No .env file found at $env_file, creating with default values"
        
        # Create a basic .env file with default values
        cat > "$env_file" << 'EOL'
# Database Configuration
DB_HOST=localhost
DB_NAME=laravel_db
# MySQL root password (hardcoded for security)
DB_PASS=Rtcv39$$

# Laravel Configuration
APP_NAME=Laravel
APP_ENV=production
APP_KEY=
APP_DEBUG=false
APP_URL=https://localhost
LARAVEL_PROJECT_NAME=default_laravel_project

# Database Configuration
DB_CONNECTION=mysql
DB_HOST=localhost
DB_PORT=3306
DB_DATABASE=laravel_db
DB_USERNAME=root
DB_PASSWORD=Rtcv39$$

# Cache and Session Configuration
CACHE_DRIVER=redis
SESSION_DRIVER=redis
QUEUE_CONNECTION=redis
REDIS_HOST=localhost
REDIS_PASSWORD=
REDIS_PORT=6379

# System Configuration
TIMEZONE=Africa/Nairobi
LANGUAGE=en_US.UTF-8
DOMAIN_NAME=localhost

# PHP Configuration
PHP_MEMORY_LIMIT=256M
PHP_UPLOAD_LIMIT=10M
PHP_MAX_EXECUTION_TIME=600
PHP_MAX_INPUT_TIME=1200
EOL
        
        if [[ $? -ne 0 ]]; then
            log_error "Failed to create default .env file at $env_file"
            return 1
        fi
        
        chmod 600 "$env_file"
        log_success "Created default .env file at $env_file"
    fi
    
    # Load the environment variables
    if [ -f "$env_file" ]; then
        # Source the .env file
        set -o allexport
        source "$env_file" || {
            log_error "Failed to source .env file at $env_file"
            set +o allexport
            return 1
        }
        set +o allexport
        
        log_info "Loaded environment from $env_file"
        echo "[INFO] Loaded environment variables from $env_file"
    else
        if type -t log_error >/dev/null 2>&1; then
            log_error ".env file does not exist at $env_file"
        else
            echo "Error: .env file does not exist at $env_file" >&2
        fi
        return 1
    fi

    # Set default values for any unset variables
    for key in "${!DEFAULTS[@]}"; do
        if [[ -z "${!key:-}" ]]; then
            declare -gx "$key"="${DEFAULTS[$key]}"
        fi
    done

    # Ensure required directories exist
    for dir in "${LOG_DIR}" \
               "${CONFIG_DIR}" \
               "${TEMP_DIR:-/tmp}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir" || {
                if type -t log_error >/dev/null 2>&1; then
                    log_error "Failed to create directory: $dir"
                else
                    echo "Error: Failed to create directory: $dir" >&2
                fi
                return 1
            }
            chmod 750 "$dir" || {
                if type -t log_warning >/dev/null 2>&1; then
                    log_warning "Failed to set permissions for: $dir"
                fi
            }
        fi
    done
    
    # Mark environment as loaded
    export ENV_LOADED=1
    
    return 0
}

# Export the load_environment function
export -f load_environment

# If this script is sourced directly, load the environment
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    load_environment "$1"
fi
