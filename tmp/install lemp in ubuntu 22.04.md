#!/bin/bash

# Updating and Upgrading System Packages
sudo apt update -y
sudo apt upgrade -y

# Install and Configure UFW Firewall
sudo apt install ufw -y
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 3306/tcp
sudo ufw --force enable


# Mysql
sudo apt update && sudo apt install mysql-server
sudo systemctl status mysql

sudo ss -lntp | grep 3306 || true
sudo mysql -e "SELECT @@socket, @@port;"

sudo mysql
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'Warhammer40K!';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost';
CREATE USER 'root'@'%' IDENTIFIED WITH mysql_native_password BY 'Warhammer40K!';
ALTER USER 'root'@'%' IDENTIFIED WITH mysql_native_password BY 'Warhammer40K!';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%';
FLUSH PRIVILEGES;

exit;

sudo mysql_secure_installation

sudo nano /etc/mysql/mysql.conf.d/mysqld.cnf
# bind-address = 127.0.0.1
bind-address = 0.0.0.0
# Remember to restart MySQL after making this change: sudo systemctl restart mysql
# Also ensure your firewall allows connections on port 3306
# You may need to run: sudo ufw allow 3306/tcp after making this change
# Make sure to restart MySQL: sudo systemctl restart mysql
# Verify the change took effect: sudo ss -tuln | grep 3306
# Check MySQL status: sudo systemctl status mysql
# If you encounter issues, check MySQL error log: sudo tail -f /var/log/mysql/error.log
# For additional troubleshooting, check MySQL configuration: sudo mysql -e "SHOW VARIABLES LIKE 'bind_address';"
# Test remote connection: mysql -u root -p -h your_server_ip
-----------------------------------------------------------------------------------------------------------------------------------------------------------

# Install Software Properties Common
sudo apt -y install software-properties-common
sudo add-apt-repository ppa:ondrej/php

sudo apt-get update -y

# Install Utilities
sudo apt install curl wget git unzip -y

# Install Nginx
sudo apt install nginx -y

# Install PHP 8.4 and Extensions
sudo apt install php8.4-enchant php8.4-odbc php8.4-pgsql php8.4-pspell php8.4-readline php8.4-snmp php8.4-sqlite3 php8.4-tidy php8.4-xsl php8.4-xdebug php8.4 php8.4-cli php8.4-common php8.4-mysql php8.4-zip php8.4-gd php8.4-mbstring php8.4-curl php8.4-xml php8.4-bcmath php8.4-intl php8.4-fpm -y

# Automated PHP Configuration Changes
PHP_INI="/etc/php/8.4/fpm/php.ini"

sudo sed -i 's/upload_max_filesize = .*/upload_max_filesize = 32M/' $PHP_INI
sudo sed -i 's/file_uploads = .*/file_uploads = On/' $PHP_INI
sudo sed -i 's/allow_url_fopen = .*/allow_url_fopen = On/' $PHP_INI
sudo sed -i "s@date.timezone = .*@date.timezone = Africa/Nairobi@" $PHP_INI
sudo sed -i 's/post_max_size = .*/post_max_size = 48M/' $PHP_INI
sudo sed -i 's/memory_limit = .*/memory_limit = 256M/' $PHP_INI
sudo sed -i 's/max_execution_time = .*/max_execution_time = 600/' $PHP_INI
sudo sed -i 's/max_input_vars = .*/max_input_vars = 5000/' $PHP_INI
sudo sed -i 's/max_input_time = .*/max_input_time = 1000/' $PHP_INI
sudo sed -i 's/cgi.fix_pathinfo = .*/cgi.fix_pathinfo = 0/' $PHP_INI

# OPcache Configuration
OPCACHE_INI="/etc/php/8.4/cli/conf.d/10-opcache.ini"

# Configure OPcache settings
sudo sed -i 's/;*opcache\.enable=.*/opcache.enable=1/' "$OPCACHE_INI"
sudo sed -i 's/;*opcache\.memory_consumption=.*/opcache.memory_consumption=256/' "$OPCACHE_INI"
sudo sed -i 's/;*opcache\.max_accelerated_files=.*/opcache.max_accelerated_files=20000/' "$OPCACHE_INI"
sudo sed -i 's/;*opcache\.revalidate_freq=.*/opcache.revalidate_freq=0/' "$OPCACHE_INI"

# FPM Pool Configuration
FPM_POOL="/etc/php/8.4/fpm/pool.d/www.conf"

# Backup original file
sudo cp "$FPM_POOL" "${FPM_POOL}.bak"

# Configure FPM pool settings using sed
sudo sed -i 's/^;*\s*pm = .*/pm = dynamic/' "$FPM_POOL"
sudo sed -i 's/^;*\s*pm\.max_children\s*=.*/pm.max_children = 50/' "$FPM_POOL"
sudo sed -i 's/^;*\s*pm\.start_servers\s*=.*/pm.start_servers = 10/' "$FPM_POOL"
sudo sed -i 's/^;*\s*pm\.min_spare_servers\s*=.*/pm.min_spare_servers = 5/' "$FPM_POOL"
sudo sed -i 's/^;*\s*pm\.max_spare_servers\s*=.*/pm.max_spare_servers = 35/' "$FPM_POOL"

# Restart PHP and Nginx to apply changes
sudo systemctl restart php8.4-fpm
sudo systemctl restart nginx

# Create user 'deployer', set up SSH keys, and configure Git
# Install Composer
# Make composer available to deployer user
# Install Node.js via NVM and set up PM2
# Ensure deployer can use node and npm
# Reload deployer's environment

echo "=== Starting deployer user & tools setup ==="

# 1. Create deployer user
adduser --gecos "" --disabled-password deployer
echo "deployer:Qwerty123!" | chpasswd   # ← CHANGE THIS PASSWORD LATER!

usermod -aG sudo deployer
usermod -aG www-data deployer
chfn -o umask=022 deployer

# 2. Set up /var/www/html ownership and permissions
mkdir -p /var/www/html
chown deployer:www-data /var/www/html
chmod 775 /var/www/html
chmod g+s /var/www/html   # New files inherit www-data group

# 3. SSH key setup for deployer
sudo -u deployer mkdir -p /home/deployer/.ssh
sudo -u deployer touch /home/deployer/.ssh/authorized_keys
sudo -u deployer chmod 700 /home/deployer/.ssh
sudo -u deployer chmod 600 /home/deployer/.ssh/authorized_keys

# Generate key pair for deployer (no passphrase)
sudo -u deployer ssh-keygen -t rsa -b 4096 -N "" -f /home/deployer/.ssh/id_rsa -q

# Add your public key for passwordless SSH login
cat << 'EOF' | sudo -u deployer tee -a /home/deployer/.ssh/authorized_keys > /dev/null
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC9h81rG/s+3hJ3nTEpxE78O+MFs1NtPfU+pn4/ZX9hs9PxoLkUrKmnLSqzNBlK1FKL3fz1dgL1WTh21rVb7qEmnh/7kBaiAObl/s4+M7BxZwwwIxj35LZOKoyAozcjdURpnblB8g7aUJ4Yayn466isFECo9BxDSfV07OOKOxbGC5GFgnkxU//XowGXgHzgJ3k76JBPFNV+gDQRa3As6XMqApn2aNAGs0wEwhxJa4FX0sEVcvZ84HUfjI7vDx6OueD5r8qgVsectHzNVAutUAQXOUfiahgOPKwlopqXGyvAfW2lirI1j9SPqBJquWelhODgG2WKTFE8AZGpXLhofEYtUSTgL/b8gca3xlZ+cfiqWMn0283oYoLBxNotsdGg4fY20EZBA0WmiyeTzYFo1RVCPpNxjJ7jUm+UQZ9wNaQsKxS0q1emG4lHusz26KKUjgCaoTgjrCBk2fwBsFkGKgvTDaiHelMgM7y5jSlspX1r45kZb5tfdxTDTBbQaOZDD5osjNXRlfcwXMP0WqRM69YOe+8Kv6YqQu+L3uv3y6eT9vGR3cv7LbTNEg2uKV3kgLT528fd9FT8fVpBFbmyeDoqQ2VJaOTkNFe7y4BY7o/v0XEFSomUXjYOKnavFdxHwXI2gA/ke2hmQYj3qvhBPdiIYujwB0FW/JTPdqnV0DACkw== business@waguramaurice.com
EOF

# 4. Git configuration for deployer
sudo -u deployer git config --global color.ui true
sudo -u deployer git config --global user.name "Wagura Maurice"
sudo -u deployer git config --global user.email "business@waguramaurice.com"

# 5. Install Composer globally
echo "=== Installing Composer globally ==="
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php -r "if (hash_file('sha384', 'composer-setup.php') === file_get_contents('https://composer.github.io/installer.sig')) { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); exit(1); } echo PHP_EOL;"
php composer-setup.php --install-dir=/usr/local/bin --filename=composer
php -r "unlink('composer-setup.php');"

# Make composer easily available to deployer
mkdir -p /home/deployer/.local/bin
ln -sf /usr/local/bin/composer /home/deployer/.local/bin/composer
chown -R deployer:deployer /home/deployer/.local
echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/deployer/.bashrc

# 6. Install Node.js 22 + npm globally (NodeSource – clean & system-wide)
echo "=== Installing Node.js 22 globally (system-wide) ==="
apt update
apt install -y ca-certificates curl gnupg

mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
     | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg

NODE_MAJOR=22
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" \
     | tee /etc/apt/sources.list.d/nodesource.list

apt update
apt install nodejs -y

# 7. Install PM2 globally and set up startup for deployer
echo "=== Installing PM2 globally ==="
npm install -g pm2

# Configure PM2 to start on boot for deployer user
su - deployer -c "pm2 startup systemd -u deployer --hp /home/deployer"

# Save PM2 process list (in case you add apps later)
su - deployer -c "pm2 save"

# Install Redis server globally
sudo apt update
sudo apt install redis-server -y

# Set password (replace if you want stronger)
sudo nano /etc/redis/redis.conf
# Find and change:
# requirepass foobared
# → become:
requirepass Qwert123!

# Secure it: Bind to localhost only (recommended)
# In the same file, ensure:
bind 127.0.0.1 ::1

# Restart to apply
sudo systemctl restart redis-server
sudo systemctl enable redis-server   # Start on boot

# Test
redis-cli
AUTH Qwert123!    # → OK
PING              # → PONG
exit

echo "=== Setup Complete! ==="
echo "You now have a secure deployer user with sudo, web folder access, SSH keys, Composer, Node.js, and PM2 ready!"
echo "Remember to:"
echo "  • Change the deployer password: sudo passwd deployer"
echo "  • Test SSH login: ssh deployer@YOUR_SERVER_IP"
echo "  • Verify tools as deployer: su - deployer && node -v && npm -v && composer --version && pm2 status"
echo "  • Check firewall status: sudo ufw status"

echo "LEMP Stack setup completed!"

exit 0