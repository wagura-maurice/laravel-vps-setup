# Define Deployer version and SHA1 hash
DEPLOYER_VERSION="6.9.0"
DEPLOYER_SHA1="35e8dcd50cf7186502f603676b972065cb68c129" # Replace with the actual SHA1 from the download page

# Download Deployer
curl -LO https://deployer.org/releases/v${DEPLOYER_VERSION}/deployer.phar

# Verify the installer
if php -r "if (hash_file('sha1', 'deployer.phar') === '${DEPLOYER_SHA1}') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('deployer.phar'); } echo PHP_EOL;"; then
    echo "Deployer installer verified successfully"
else
    echo "Deployer installer verification failed"
    exit 1
fi

# Make Deployer available system-wide and executable
sudo mv deployer.phar /usr/local/bin/dep
sudo chmod +x /usr/local/bin/dep