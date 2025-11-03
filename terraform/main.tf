terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.0"
}

provider "aws" {
  region = var.aws_region
}

# Get latest Ubuntu 22.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Create VPC
resource "aws_vpc" "snipeit_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "snipeit-vpc"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "snipeit_igw" {
  vpc_id = aws_vpc.snipeit_vpc.id

  tags = {
    Name = "snipeit-igw"
  }
}

# Create Public Subnet
resource "aws_subnet" "snipeit_subnet" {
  vpc_id                  = aws_vpc.snipeit_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "snipeit-subnet"
  }
}

# Get available AZs
data "aws_availability_zones" "available" {
  state = "available"
}

# Create Route Table
resource "aws_route_table" "snipeit_rt" {
  vpc_id = aws_vpc.snipeit_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.snipeit_igw.id
  }

  tags = {
    Name = "snipeit-rt"
  }
}

# Associate Route Table with Subnet
resource "aws_route_table_association" "snipeit_rta" {
  subnet_id      = aws_subnet.snipeit_subnet.id
  route_table_id = aws_route_table.snipeit_rt.id
}

# Create Security Group
resource "aws_security_group" "snipeit_sg" {
  name        = "snipeit-security-group"
  description = "Security group for Snipe-IT application"
  vpc_id      = aws_vpc.snipeit_vpc.id

  # SSH
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Nginx Proxy Manager Admin
  ingress {
    description = "NPM Admin"
    from_port   = 81
    to_port     = 81
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "snipeit-sg"
  }
}

# Create EC2 Instance
resource "aws_instance" "snipeit" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.key_name

  subnet_id                   = aws_subnet.snipeit_subnet.id
  vpc_security_group_ids      = [aws_security_group.snipeit_sg.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = {
    Name = "snipeit-server"
  }
}
