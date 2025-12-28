# Laravel VPS Setup System

A comprehensive, modular system for setting up a production-ready Laravel environment on Ubuntu 22.04 VPS.

## Overview

This system provides a complete, production-ready Laravel development and deployment environment with:

- **Nginx** web server
- **MySQL 8.0** database server
- **PHP 8.4** with all Laravel-required extensions
- **Redis 7.0** for caching and session management
- **Composer** dependency manager
- **Node.js 22** and NPM
- Dedicated **deployer** user with sudo privileges and SSH key management
- Laravel project pre-installed and configured
- Proper file permissions and security configurations
- Environment optimized for Laravel applications
- Automated SSL certificate management with Certbot
- Centralized environment variable management via `.env` file

## System Requirements

### Hardware Requirements

- **CPU**: 2 cores (4+ recommended)
- **RAM**: 2GB minimum (4GB+ recommended)
- **Storage**: 20GB minimum (SSD recommended)
- **Network**: 100 Mbps minimum (1 Gbps recommended)

### Software Requirements

- **OS**: Ubuntu 22.04 LTS (recommended)
- **User**: Root or sudo privileges

## Installation

### Quick Setup

To set up the complete Laravel environment on a fresh Ubuntu 22.04 VPS:

1. Clone this repository:

```bash
git clone https://github.com/wagura-maurice/laravel-vps-setup.git
cd laravel-vps-setup
```

2. Make the setup script executable:

```bash
chmod +x laravel-setup-system.sh
```

3. Run the setup script:

```bash
sudo ./laravel-setup-system.sh
```

### Environment Configuration

Before running the setup, configure your environment variables in the `.env` file at the project root:

```bash
# Database Configuration
DB_HOST=localhost
DB_NAME=laravel_db
DB_USER=deployer
DB_PASS=Qwerty123!
DB_ROOT_PASS=!Qwerty123!

# Laravel Configuration
APP_NAME=Laravel
APP_ENV=production
APP_DEBUG=false
APP_URL=https://your-domain.com  # IMPORTANT: Set your actual domain here
LARAVEL_PROJECT_NAME=default_laravel_project

# System Configuration
TIMEZONE=Africa/Nairobi
DOMAIN_NAME=your-domain.com  # Your actual domain name

# Deployer User Configuration
DEPLOYER_USER=deployer
DEPLOYER_PASS=Qwerty123!

# PHP Configuration
PHP_MEMORY_LIMIT=256M
PHP_UPLOAD_LIMIT=10M
PHP_MAX_EXECUTION_TIME=600

# Redis Configuration
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=
```

### Modular Installation

The system is built with a modular approach. You can run individual components:

**Installation Scripts:**

- `src/utilities/install/install-system.sh` - System updates, Nginx, Node.js, and deployer user
- `src/utilities/install/install-php.sh` - PHP 8.4 and required extensions
- `src/utilities/install/install-mysql.sh` - MySQL 8.0 installation and configuration
- `src/utilities/install/install-redis.sh` - Redis 7.0 installation
- `src/utilities/install/install-composer.sh` - Composer installation
- `src/utilities/install/install-laravel.sh` - Laravel project creation
- `src/utilities/install/install-certbot.sh` - Certbot installation for SSL

**Configuration Scripts:**

- `src/utilities/configure/configure-nginx.sh` - Nginx configuration for Laravel
- `src/utilities/configure/configure-php.sh` - PHP fine-tuning for Laravel
- `src/utilities/configure/configure-redis.sh` - Redis configuration for Laravel
- `src/utilities/configure/configure-deployer.sh` - Deployer user setup with SSH keys
- `src/utilities/configure/configure-system.sh` - System-wide settings (timezone, locale, fail2ban)
- `src/utilities/configure/configure-certbot.sh` - Certbot configuration

## User Accounts

The system creates a dedicated `deployer` user for managing Laravel applications:

- **Username**: `deployer`
- **Password**: Configurable via `.env` (default: `Qwerty123!`)
- **Sudo privileges**: Yes (can restart PHP-FPM without password)
- **Home directory**: `/home/deployer`
- **Owns**: `/var/www/html` directory
- **Database access**: Can access MySQL with password from `.env`
- **SSH Keys**: Automatically generated with server IP in comment
- **Git Configuration**: Pre-configured with your credentials
- **Public SSH Key**: Displayed at end of deployer configuration for GitHub integration

## Database Configuration

- **Root password**: `!Qwerty123!`
- **Laravel database**: `laravel_db`
- **Laravel database user**: `deployer` with password `Qwerty123!`
- **Deployer database user**: `deployer` with password `Qwerty123!`
- **Remote access**: Enabled for deployer user

## Application Location

- **Laravel project**: `/var/www/html/default_laravel_project`
- **Public directory**: `/var/www/html/default_laravel_project/public`
- **Nginx configuration**: `/etc/nginx/sites-available/laravel`

## Service Management

A management script is provided for controlling Laravel services:

```bash
laravel-manager {start|stop|restart|status}
```

## Post-Installation Steps

1. **Verify Domain Configuration**: Ensure `DOMAIN_NAME` and `APP_URL` in root `.env` are correct
2. **Set up SSL Certificate**:
   ```bash
   sudo certbot --nginx -d your-domain.com
   ```
3. **Verify Laravel Configuration**: Check `/var/www/html/{LARAVEL_PROJECT_NAME}/.env` is properly configured
4. **Run Laravel Migrations**:
   ```bash
   sudo -u deployer php artisan migrate --force
   ```
5. **Add Deployer SSH Key to GitHub**: Copy the public key displayed at the end of deployer configuration
6. **Set up Laravel Queues** (if needed):
   ```bash
   sudo systemctl enable --now redis-server
   sudo -u deployer php artisan queue:work --daemon
   ```

## Environment Variables

All environment variables are managed through the root `.env` file. The system uses a centralized environment loader (`src/core/env-loader.sh`) that:

- Loads variables from the project root `.env` file
- Provides default values for missing variables
- Ensures consistency across all installation and configuration scripts
- Automatically creates a default `.env` if one doesn't exist

Key variables include:

- `APP_ENV=production`
- `APP_DEBUG=false`
- `APP_URL` - Must be set to your actual domain (no localhost fallback)
- `TIMEZONE=Africa/Nairobi`
- Database connection settings (DB_HOST, DB_NAME, DB_USER, DB_PASS)
- Redis configuration (REDIS_HOST, REDIS_PORT)
- Cache and session drivers configured for Redis
- Queue driver configured for Redis

## Security Features

- UFW firewall configured with secure defaults
- Proper file permissions for Laravel directories
- PHP configured with security best practices
- MySQL secured with strong authentication
- SSL certificate support via Certbot
- Restricted access to sensitive files

## Deployment Workflow

As the deployer user, you can deploy Laravel applications:

```bash
# Switch to deployer user
sudo su - deployer

# Navigate to Laravel project
cd /var/www/html/default_laravel_project

# Pull latest code
git pull origin main

# Install/update dependencies
composer install

# Run migrations
php artisan migrate --force

# Clear caches
php artisan config:clear
php artisan cache:clear
php artisan route:clear
php artisan view:clear

# Optimize
php artisan optimize:clear
php artisan config:cache
php artisan route:cache
php artisan view:cache

# Restart PHP-FPM
sudo systemctl reload php8.4-fpm
```

## Architecture

The system uses a modular architecture:

### Core Modules (`src/core/`)

- **env-loader.sh**: Centralized environment variable loading
- **logging.sh**: Consistent logging across all scripts
- **common-functions.sh**: Shared utility functions
- **config-manager.sh**: Configuration template management

### Installation Scripts (`src/utilities/install/`)

Each script handles a specific component installation:

- System packages and tools
- PHP 8.4 and extensions
- MySQL 8.0
- Redis 7.0
- Composer
- Laravel project
- Certbot

### Configuration Scripts (`src/utilities/configure/`)

Each script configures a specific component:

- Nginx server blocks
- PHP settings and PHP-FPM pools
- Redis configuration
- System settings (timezone, locale, fail2ban)
- Deployer user setup
- Certbot automation

## Maintenance

### Regular Maintenance Tasks

1. **System updates**: Run `sudo apt update && sudo apt upgrade` regularly
2. **Laravel cache clearing**: Use `php artisan cache:clear` as needed
3. **Log rotation**: Nginx, PHP, and Laravel logs are automatically rotated
4. **Database maintenance**: MySQL is configured with automatic optimization
5. **SSL certificate renewal**: Certbot automatically renews certificates via systemd timer
6. **Redis monitoring**: Check Redis memory usage and performance
7. **PHP-FPM monitoring**: Monitor PHP-FPM pool status and adjust as needed

## Deployer User Features

The deployer user is fully configured for Laravel deployments:

### SSH Key Management

- SSH key pair automatically generated if it doesn't exist
- Public key displayed at end of configuration for easy GitHub integration
- Server IP automatically detected and used in SSH key comment
- Root's `authorized_keys` copied to deployer for seamless access

### Git Configuration

- Pre-configured with your Git credentials
- Ready for repository cloning and pulling

### Deployment Script

A deployment script is available at `/home/deployer/deploy-laravel.sh` that:

- Pulls latest code from Git
- Installs/updates Composer dependencies
- Runs database migrations
- Clears and caches Laravel configurations
- Optimizes the application
- Reloads PHP-FPM

### Sudo Privileges

- Can restart/reload PHP-FPM without password prompt
- Full sudo access for system management

### Laravel Tools

- Laravel Installer installed globally
- Deployer (deployment tool) available via Composer

## Troubleshooting

### Common Issues

1. **Permission Issues**:

   ```bash
   sudo chown -R deployer:deployer /var/www/html/default_laravel_project
   sudo chmod -R 755 /var/www/html/default_laravel_project
   ```

2. **Service Status**:

   ```bash
   sudo systemctl status nginx
   sudo systemctl status php8.4-fpm
   sudo systemctl status mysql
   sudo systemctl status redis-server
   ```

3. **Check Logs**:

   ```bash
   # Laravel logs
   sudo tail -f /var/www/html/default_laravel_project/storage/logs/laravel.log

   # Nginx logs
   sudo tail -f /var/log/nginx/laravel_error.log

   # PHP-FPM logs
   sudo tail -f /var/log/php8.4-fpm.log
   ```

## Code Quality

The codebase has been reviewed and improved:

- ✅ Removed duplicate function definitions
- ✅ Standardized logging functions (all use `log_*` instead of `print_*`)
- ✅ Fixed environment variable loading consistency
- ✅ Corrected script path calculations
- ✅ Fixed undefined variable references
- ✅ Improved error handling and validation
- ✅ Enhanced documentation and comments

## Recent Improvements

- **Centralized Environment Management**: All scripts now use the unified `load_environment()` function
- **SSH Key Management**: Automatic SSH key generation with server IP detection
- **Git Configuration**: Pre-configured deployer user with your credentials
- **Redis Integration**: Full Redis support for caching, sessions, and queues
- **Improved Error Handling**: Better error messages and validation throughout
- **Code Cleanup**: Removed duplicate functions and standardized patterns

## Support

For support, feature requests, or contributions, please contact the project maintainers.

## License

This project is open source and available under the MIT License.
