#!/bin/bash
set -e

dnf update -y

dnf install -y httpd php php-mysqlnd php-gd php-xml php-mbstring php-intl php-zip mariadb105-server wget tar

systemctl enable --now httpd
systemctl enable --now mariadb

# Generate a random database password
DB_PASSWORD=$(openssl rand -hex 24)

# Create the WordPress database and user
mysql <<SQL
CREATE DATABASE wordpress;
CREATE USER 'wp_user'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON wordpress.* TO 'wp_user'@'localhost';
FLUSH PRIVILEGES;
SQL

# Download and extract WordPress
cd /tmp
wget https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz

# Copy WordPress files into Apache's web directory
cp -a wordpress/. /var/www/html/

# Create WordPress configuration
cd /var/www/html

cp wp-config-sample.php wp-config.php

# Configure database connection
sed -i "s/database_name_here/wordpress/" wp-config.php
sed -i "s/username_here/wp_user/" wp-config.php
sed -i "s/password_here/${DB_PASSWORD}/" wp-config.php

# Set WordPress file ownership
chown -R apache:apache /var/www/html

# Set directory permissions
find /var/www/html -type d -exec chmod 755 {} \;

# Set file permissions
find /var/www/html -type f -exec chmod 644 {} \;

# Protect WordPress configuration
chmod 640 /var/www/html/wp-config.php

# Restart Apache to apply configuration
systemctl restart httpd

