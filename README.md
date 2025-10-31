# Snipe-IT Deployment

A complete Docker-based deployment solution for [Snipe-IT](https://snipeitapp.com/) asset management system with SSL support via Nginx Proxy Manager.

## What's Included

- **Snipe-IT** - Open-source IT asset management
- **MySQL 8.0** - Database
- **Nginx Proxy Manager** - Reverse proxy with automatic SSL (Let's Encrypt)
- **Docker Compose** - Container orchestration

## Architecture

```
Internet (HTTPS)
    ↓
Nginx Proxy Manager (SSL termination)
    ↓
Snipe-IT Application
    ↓
MySQL Database
```

All services run in isolated Docker containers on a private network.

## Prerequisites

- Ubuntu 22.04 LTS (or similar Linux distribution)
- Docker and Docker Compose installed
- Domain name pointing to your server
- Ports 80, 443, and 81 open in firewall

## Deployment Options

### Option 1: Automated Terraform Deployment (Recommended)

Automatically provisions AWS infrastructure, installs Docker, and deploys all services.

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars  # Edit with your values
terraform init
terraform apply
```

📖 See [terraform/README.md](terraform/README.md) for detailed instructions.

---

### Option 2: Manual Deployment

For existing servers or non-AWS deployments.

#### 1. Install Docker

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Install Docker Compose plugin
sudo apt install docker-compose-plugin -y
```

#### 2. Clone/Copy Project Files

```bash
mkdir -p ~/snipeit
cd ~/snipeit
```

Copy these files to the server:
- `docker-compose.yml`
- `.env` (create from example below)

#### 3. Create .env File

```bash
nano .env
```

**Minimal required configuration:**

```env
# Basic Settings
APP_ENV=production
APP_DEBUG=false
APP_KEY=base64:YOUR_APP_KEY_HERE
APP_URL=https://your-domain.com
APP_TIMEZONE='America/Los_Angeles'
APP_LOCALE=en-US

# Storage
PRIVATE_FILESYSTEM_DISK=local
PUBLIC_FILESYSTEM_DISK=local_public

# Database (container names, not IPs)
MYSQL_PORT_3306_TCP_ADDR=mysql
MYSQL_PORT_3306_TCP_PORT=3306
MYSQL_DATABASE=snipeit
MYSQL_USER=snipeit
MYSQL_PASSWORD=your-secure-password
MYSQL_ROOT_PASSWORD=your-root-password

# Mail Configuration
MAIL_MAILER=smtp
MAIL_HOST=smtp.office365.com
MAIL_PORT=587
MAIL_USERNAME=your-email@example.com
MAIL_PASSWORD=your-email-password
MAIL_FROM_ADDR=your-email@example.com
MAIL_FROM_NAME='Snipe-IT'

# Other Required Settings
IMAGE_LIB=gd
SESSION_LIFETIME=12000
LOG_CHANNEL=stderr
```

**Generate APP_KEY:**
```bash
docker run --rm snipe/snipe-it php artisan key:generate --show
```

#### 4. Start Services

```bash
docker compose up -d
```

Wait 2-3 minutes for all services to start, especially MySQL initialization.

#### 5. Verify Containers Are Running

```bash
docker ps
```

You should see 3 containers:
- `snipeit-mysql-1`
- `snipeit-app-1`
- `snipeit-nginx-proxy-manager-1`

---

## Post-Deployment Configuration

### 1. Configure DNS

Update your domain's DNS A record:

```
Type: A
Name: your-subdomain (e.g., snipeit)
Value: YOUR_SERVER_IP
TTL: 3600
```

Verify DNS propagation:
```bash
nslookup your-domain.com
```

### 2. Setup SSL Certificate

1. **Access Nginx Proxy Manager admin panel:**
   ```
   http://YOUR_SERVER_IP:81
   ```

2. **Login with default credentials:**
   - Email: `admin@example.com`
   - Password: `changeme`
   - **⚠️ Change password immediately after first login**

3. **Add Proxy Host:**
   - Click **Hosts** → **Proxy Hosts** → **Add Proxy Host**

   **Details tab:**
   - Domain Names: `your-domain.com`
   - Scheme: `http`
   - Forward Hostname/IP: `app`
   - Forward Port: `80`
   - ✅ Block Common Exploits
   - ✅ Websockets Support

   **SSL tab:**
   - ✅ Request a new SSL Certificate
   - ✅ Force SSL
   - ✅ HTTP/2 Support
   - ✅ Agree to Let's Encrypt Terms
   - Email: `your-email@example.com`

   - Click **Save**

4. **Access Snipe-IT:**
   ```
   https://your-domain.com
   ```

### 3. Complete Snipe-IT Setup

Follow the on-screen setup wizard to:
- Create admin account
- Configure company settings
- Set up asset categories

## Management

### View Logs

```bash
# All containers
docker compose logs -f

# Specific container
docker logs snipeit-app-1 -f
docker logs snipeit-mysql-1 -f
docker logs snipeit-nginx-proxy-manager-1 -f
```

### Restart Services

```bash
# Restart all
docker compose restart

# Restart specific service
docker restart snipeit-app-1
```

### Stop Services

```bash
docker compose down
```

### Update Snipe-IT

```bash
docker compose pull
docker compose up -d
```

### Backup

**Database backup:**
```bash
docker exec snipeit-mysql-1 mysqldump -u root -p'your-root-password' snipeit > backup-$(date +%Y%m%d).sql
```

**Uploaded files backup:**
```bash
docker cp snipeit-app-1:/var/lib/snipeit ./snipeit-backup-$(date +%Y%m%d)
```

**Restore database:**
```bash
docker exec -i snipeit-mysql-1 mysql -u root -p'your-root-password' snipeit < backup-YYYYMMDD.sql
```

## Troubleshooting

### Check Container Status

```bash
docker ps -a
```

### Container Won't Start

```bash
# Check logs
docker logs snipeit-app-1 --tail 100

# Common issues:
# - Database not ready (wait 60 seconds)
# - Invalid .env configuration
# - Port conflicts
```

### Database Connection Errors

```bash
# Verify MySQL is ready
docker logs snipeit-mysql-1 | grep "ready for connections"

# Test connectivity from app
docker exec snipeit-app-1 php artisan migrate:status

# Restart app container
docker restart snipeit-app-1
```

### 504 Gateway Timeout

```bash
# Check if app is listening on port 80
docker exec snipeit-nginx-proxy-manager-1 curl -I http://app:80

# If fails, restart app container
docker restart snipeit-app-1

# Wait 60 seconds for migrations to complete
docker logs snipeit-app-1 -f
```

### SSL Certificate Fails

1. Verify DNS points to your server: `nslookup your-domain.com`
2. Ensure ports 80 and 443 are open
3. Check NPM logs: `docker logs snipeit-nginx-proxy-manager-1`
4. Try deleting and recreating the proxy host

### Port Already in Use

```bash
# Find what's using the port
sudo lsof -i :80
sudo lsof -i :443
sudo lsof -i :81

# Stop conflicting service (e.g., nginx)
sudo systemctl stop nginx
sudo systemctl disable nginx

# Restart containers
docker compose up -d
```

### Access NPM Admin After Lockout

```bash
# Reset NPM admin password
docker exec -it snipeit-nginx-proxy-manager-1 /bin/bash
npx npm-password-reset
```

## Security Best Practices

- ✅ Use strong, unique passwords for all services
- ✅ Change default NPM admin credentials
- ✅ Keep containers updated regularly
- ✅ Enable firewall (UFW) and limit SSH access
- ✅ Use HTTPS only (Force SSL in NPM)
- ✅ Regular backups of database and uploads
- ✅ Don't commit `.env` file to git
- ✅ Restrict NPM admin panel access (port 81) by IP if possible

## File Structure

```
snipeit/
├── docker-compose.yml       # Container definitions
├── .env                     # Configuration (DO NOT COMMIT)
├── .gitignore              # Excludes sensitive files
├── README.md               # This file
└── terraform/              # Automated deployment
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    ├── user-data.sh
    ├── terraform.tfvars.example
    └── README.md
```

## Environment Variables Reference

See `.env` file for complete list. Key variables:

| Variable | Description | Example |
|----------|-------------|---------|
| `APP_URL` | Your domain with https:// | `https://snipeit.example.com` |
| `APP_KEY` | Laravel encryption key | Generate with artisan |
| `MYSQL_PASSWORD` | Database password | Strong random password |
| `MAIL_HOST` | SMTP server | `smtp.office365.com` |
| `MAIL_USERNAME` | SMTP username | `user@example.com` |

## Support

- **Snipe-IT Documentation:** https://snipe-it.readme.io/
- **Docker Compose Docs:** https://docs.docker.com/compose/
- **Nginx Proxy Manager:** https://nginxproxymanager.com/

## Contributing

Feel free to open issues or submit pull requests for improvements.

## License

This deployment configuration is provided as-is. Snipe-IT is licensed under AGPL-3.0.

---

**Need help?** Check logs first:
```bash
docker compose logs -f
```

**Quick health check:**
```bash
docker ps  # All 3 containers should be "Up"
curl http://localhost  # Should return HTML
```
