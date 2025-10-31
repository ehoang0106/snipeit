#!/bin/bash
set -e

# Log output to file
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "Starting user data script..."

# Update system
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# Install dependencies
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Install Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Enable and start Docker
systemctl enable docker
systemctl start docker

# Add ubuntu user to docker group
usermod -aG docker ubuntu

# Create application directory
mkdir -p /home/ubuntu/snipeit
cd /home/ubuntu/snipeit

# Create .env file
cat > .env << 'EOF'
# --------------------------------------------
# REQUIRED: DOCKER SPECIFIC SETTINGS
# --------------------------------------------
APP_VERSION=
APP_PORT=8000

# --------------------------------------------
# REQUIRED: BASIC APP SETTINGS
# --------------------------------------------
APP_ENV=production
APP_DEBUG=false
APP_KEY=${app_key}
APP_URL=https://${domain_name}
APP_TIMEZONE='America/Los_Angeles'
APP_LOCALE=en-US
MAX_RESULTS=500

# --------------------------------------------
# REQUIRED: UPLOADED FILE STORAGE SETTINGS
# --------------------------------------------
PRIVATE_FILESYSTEM_DISK=local
PUBLIC_FILESYSTEM_DISK=local_public

# --------------------------------------------
# REQUIRED: DATABASE SETTINGS
# --------------------------------------------
MYSQL_PORT_3306_TCP_ADDR=mysql
MYSQL_PORT_3306_TCP_PORT=3306
MYSQL_DATABASE=${mysql_database}
MYSQL_USER=${mysql_user}
MYSQL_PASSWORD=${mysql_password}
MYSQL_ROOT_PASSWORD=${mysql_root_password}

# --------------------------------------------
# OPTIONAL: SSL DATABASE SETTINGS
# --------------------------------------------
DB_SSL=false
DB_SSL_IS_PAAS=false
DB_SSL_KEY_PATH=null
DB_SSL_CERT_PATH=null
DB_SSL_CA_PATH=null
DB_SSL_CIPHER=null
DB_SSL_VERIFY_SERVER=null

# --------------------------------------------
# REQUIRED: OUTGOING MAIL SERVER SETTINGS
# --------------------------------------------
MAIL_MAILER=smtp
MAIL_HOST=${mail_host}
MAIL_PORT=${mail_port}
MAIL_USERNAME=${mail_username}
MAIL_PASSWORD=${mail_password}
MAIL_TLS_VERIFY_PEER=true
MAIL_FROM_ADDR=${mail_from_addr}
MAIL_FROM_NAME='Snipe-IT'
MAIL_REPLYTO_ADDR=${mail_from_addr}
MAIL_REPLYTO_NAME='Snipe-IT'
MAIL_AUTO_EMBED_METHOD='attachment'

# --------------------------------------------
# REQUIRED: DATA PROTECTION
# --------------------------------------------
ALLOW_BACKUP_DELETE=true
ALLOW_DATA_PURGE=false

# --------------------------------------------
# REQUIRED: IMAGE LIBRARY
# --------------------------------------------
IMAGE_LIB=gd

# --------------------------------------------
# OPTIONAL: BACKUP SETTINGS
# --------------------------------------------
MAIL_BACKUP_NOTIFICATION_DRIVER=null
MAIL_BACKUP_NOTIFICATION_ADDRESS=null
BACKUP_ENV=true

# --------------------------------------------
# OPTIONAL: SESSION SETTINGS
# --------------------------------------------
SESSION_LIFETIME=12000
EXPIRE_ON_CLOSE=false
ENCRYPT=false
COOKIE_NAME=snipeit_session
COOKIE_DOMAIN=null
SECURE_COOKIES=false
API_TOKEN_EXPIRATION_YEARS=40

# --------------------------------------------
# OPTIONAL: SECURITY HEADER SETTINGS
# --------------------------------------------
APP_TRUSTED_PROXIES=192.168.1.1,10.0.0.1,172.16.0.0/12
ALLOW_IFRAMING=false
REFERRER_POLICY=same-origin
ENABLE_CSP=false
CORS_ALLOWED_ORIGINS=null
ENABLE_HSTS=false

# --------------------------------------------
# OPTIONAL: CACHE SETTINGS
# --------------------------------------------
CACHE_DRIVER=file
SESSION_DRIVER=file
QUEUE_DRIVER=sync
CACHE_PREFIX=snipeit

# --------------------------------------------
# OPTIONAL: REDIS SETTINGS
# --------------------------------------------
REDIS_HOST=null
REDIS_PASSWORD=null
REDIS_PORT=6379

# --------------------------------------------
# OPTIONAL: MEMCACHED SETTINGS
# --------------------------------------------
MEMCACHED_HOST=null
MEMCACHED_PORT=null

# --------------------------------------------
# OPTIONAL: PUBLIC S3 Settings
# --------------------------------------------
PUBLIC_AWS_SECRET_ACCESS_KEY=null
PUBLIC_AWS_ACCESS_KEY_ID=null
PUBLIC_AWS_DEFAULT_REGION=null
PUBLIC_AWS_BUCKET=null
PUBLIC_AWS_URL=null
PUBLIC_AWS_BUCKET_ROOT=null

# --------------------------------------------
# OPTIONAL: PRIVATE S3 Settings
# --------------------------------------------
PRIVATE_AWS_ACCESS_KEY_ID=null
PRIVATE_AWS_SECRET_ACCESS_KEY=null
PRIVATE_AWS_DEFAULT_REGION=null
PRIVATE_AWS_BUCKET=null
PRIVATE_AWS_URL=null
PRIVATE_AWS_BUCKET_ROOT=null

# --------------------------------------------
# OPTIONAL: AWS Settings
# --------------------------------------------
AWS_ACCESS_KEY_ID=null
AWS_SECRET_ACCESS_KEY=null
AWS_DEFAULT_REGION=null

# --------------------------------------------
# OPTIONAL: LOGIN THROTTLING
# --------------------------------------------
LOGIN_MAX_ATTEMPTS=5
LOGIN_LOCKOUT_DURATION=60
RESET_PASSWORD_LINK_EXPIRES=900

# --------------------------------------------
# OPTIONAL: MISC
# --------------------------------------------
LOG_CHANNEL=stderr
LOG_MAX_DAYS=10
APP_LOCKED=false
APP_CIPHER=AES-256-CBC
APP_FORCE_TLS=false
GOOGLE_MAPS_API=
LDAP_MEM_LIM=500M
LDAP_TIME_LIM=600
EOF

# Create docker-compose.yml
cat > docker-compose.yml << 'EOF'
# Compose file for production.

volumes:
  db_data:
  storage:
  npm_data:
  npm_ssl:
  npm_db:

networks:
  snipeit_network:
    driver: bridge

services:
  mysql:
    image: mysql:8.0
    restart: always
    volumes:
      - db_data:/var/lib/mysql
    networks:
      - snipeit_network
    environment:
      MYSQL_ROOT_PASSWORD: $${MYSQL_ROOT_PASSWORD:-rootpassword}
      MYSQL_DATABASE: $${MYSQL_DATABASE:-snipeit}
      MYSQL_USER: $${MYSQL_USER:-snipeit}
      MYSQL_PASSWORD: $${MYSQL_PASSWORD:-snipeitpassword}
    command: --default-authentication-plugin=mysql_native_password

  app:
    image: snipe/snipe-it:$${APP_VERSION:-latest}
    restart: always
    volumes:
      - storage:/var/lib/snipeit
    env_file:
      - .env
    networks:
      - snipeit_network
    expose:
      - "80"
    depends_on:
      - mysql

  nginx-proxy-manager:
    image: jc21/nginx-proxy-manager:latest
    restart: always
    ports:
      - "80:80"      # HTTP
      - "443:443"    # HTTPS
      - "81:81"      # Admin Web UI
    volumes:
      - npm_data:/data
      - npm_ssl:/etc/letsencrypt
    networks:
      - snipeit_network
    environment:
      DB_SQLITE_FILE: "/data/database.sqlite"
EOF

# Set ownership
chown -R ubuntu:ubuntu /home/ubuntu/snipeit

# Start Docker Compose
cd /home/ubuntu/snipeit
docker compose up -d

echo "User data script completed successfully!"
echo "Snipe-IT is starting up. Please wait 2-3 minutes for all services to be ready."
echo "Access NPM admin at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):81"
echo "Default NPM credentials: admin@example.com / changeme"
