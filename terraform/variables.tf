variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-west-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "key_name" {
  description = "Name of the SSH key pair to use for the instance"
  type        = string
}

variable "domain_name" {
  description = "Domain name for Snipe-IT (e.g., test.khoah.com)"
  type        = string
  default     = "test.khoah.com"
}

# Database variables
variable "mysql_database" {
  description = "MySQL database name"
  type        = string
  default     = "snipeit"
}

variable "mysql_user" {
  description = "MySQL username"
  type        = string
  default     = "snipeit"
}

variable "mysql_password" {
  description = "MySQL password"
  type        = string
  sensitive   = true
}

variable "mysql_root_password" {
  description = "MySQL root password"
  type        = string
  sensitive   = true
}

# Application variables
variable "app_key" {
  description = "Laravel application key (base64 encoded)"
  type        = string
  sensitive   = true
}

# Mail configuration
variable "mail_host" {
  description = "SMTP mail host"
  type        = string
  default     = "smtp.office365.com"
}

variable "mail_port" {
  description = "SMTP mail port"
  type        = string
  default     = "587"
}

variable "mail_username" {
  description = "SMTP mail username"
  type        = string
}

variable "mail_password" {
  description = "SMTP mail password"
  type        = string
  sensitive   = true
}

variable "mail_from_addr" {
  description = "Mail from address"
  type        = string
}
