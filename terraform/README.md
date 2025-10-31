# Snipe-IT AWS Terraform Infrastructure

This Terraform configuration automatically provisions a complete Snipe-IT infrastructure on AWS with:
- EC2 instance (Ubuntu 22.04, t3.medium)
- VPC with public subnet
- Security groups (ports 22, 80, 443, 81)
- Docker and Docker Compose installed
- MySQL database container
- Nginx Proxy Manager for SSL
- Snipe-IT application

## Prerequisites

1. **Terraform installed** (v1.0+)
   ```bash
   # Install on Linux
   wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
   unzip terraform_1.6.0_linux_amd64.zip
   sudo mv terraform /usr/local/bin/
   ```

2. **AWS CLI configured** with credentials
   ```bash
   aws configure
   ```

3. **SSH key pair created** in AWS EC2 console
   - Go to EC2 → Key Pairs → Create Key Pair
   - Download the `.pem` file
   - Save it to `~/.ssh/` and set permissions: `chmod 400 ~/.ssh/your-key.pem`

## Setup Instructions

### 1. Configure Variables

Copy the example variables file and edit it with your values:

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
```

**Required variables to update:**
- `key_name` - Your AWS SSH key pair name (without .pem)
- `domain_name` - Your domain (e.g., test.khoah.com)
- `mysql_password` - Strong MySQL password
- `mysql_root_password` - Strong MySQL root password
- `mail_username` - Your SMTP username
- `mail_password` - Your SMTP password
- `mail_from_addr` - Your from email address

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Review the Plan

```bash
terraform plan
```

This shows what resources will be created.

### 4. Apply Configuration

```bash
terraform apply
```

Type `yes` when prompted. The infrastructure will be created in ~5 minutes.

### 5. Get Outputs

After successful deployment:

```bash
terraform output
```

You'll see:
- **instance_public_ip** - Server IP address
- **npm_admin_url** - Nginx Proxy Manager admin panel URL
- **ssh_command** - Command to SSH into the server

### 6. Configure DNS

Update your domain's DNS A record to point to the `instance_public_ip`:

```
Type: A
Name: test (or your subdomain)
Value: [instance_public_ip from terraform output]
TTL: 3600
```

### 7. Setup SSL Certificate

1. Wait 5-10 minutes for the server to finish installing Docker and starting containers

2. Access Nginx Proxy Manager admin panel:
   ```
   http://[instance_public_ip]:81
   ```

3. Login with default credentials:
   - Email: `admin@example.com`
   - Password: `changeme`

4. Change the password when prompted

5. Add Proxy Host:
   - Hosts → Proxy Hosts → Add Proxy Host
   - **Details tab:**
     - Domain Names: `test.khoah.com` (your domain)
     - Scheme: `http`
     - Forward Hostname/IP: `app`
     - Forward Port: `80`
     - ✅ Block Common Exploits
   - **SSL tab:**
     - ✅ Request a new SSL Certificate
     - ✅ Force SSL
     - ✅ HTTP/2 Support
     - ✅ Agree to Let's Encrypt Terms
     - Email: your-email@example.com
   - Click Save

6. Access your Snipe-IT installation:
   ```
   https://test.khoah.com
   ```

## Troubleshooting

### Check if containers are running

```bash
ssh -i ~/.ssh/your-key.pem ubuntu@[instance_public_ip]
cd ~/snipeit
docker ps
```

### View container logs

```bash
docker logs snipeit-app-1 --tail 50
docker logs snipeit-mysql-1 --tail 50
docker logs snipeit-nginx-proxy-manager-1 --tail 50
```

### Restart containers

```bash
cd ~/snipeit
docker compose restart
```

### View user-data script logs

```bash
ssh -i ~/.ssh/your-key.pem ubuntu@[instance_public_ip]
sudo tail -f /var/log/user-data.log
```

## Updating Configuration

To modify the infrastructure:

1. Edit `terraform.tfvars` or `main.tf`
2. Run `terraform plan` to preview changes
3. Run `terraform apply` to apply changes

## Destroying Infrastructure

To remove all resources:

```bash
terraform destroy
```

Type `yes` when prompted. This will delete:
- EC2 instance
- Security groups
- VPC and networking resources
- All data (make backups first!)

## Security Notes

- **Never commit** `terraform.tfvars` to version control (contains secrets)
- Add `terraform.tfvars` to `.gitignore`
- Use AWS Secrets Manager for production environments
- Restrict SSH access by updating security group CIDR blocks
- Change default NPM admin credentials immediately

## Architecture

```
Internet
    │
    ├──> Port 80/443 (HTTPS) ──> Nginx Proxy Manager ──> Snipe-IT App
    ├──> Port 81 (NPM Admin)
    └──> Port 22 (SSH)

Internal Docker Network:
    ├── nginx-proxy-manager (ports 80, 443, 81)
    ├── app (Snipe-IT)
    └── mysql (database)
```

## Cost Estimate

- t3.medium instance: ~$30/month
- 30GB EBS storage: ~$3/month
- Data transfer: Variable
- **Total: ~$33-40/month**

## Support

For issues:
1. Check logs: `docker logs [container-name]`
2. Verify DNS: `nslookup your-domain.com`
3. Check security groups in AWS console
4. Review `/var/log/user-data.log` for startup issues
