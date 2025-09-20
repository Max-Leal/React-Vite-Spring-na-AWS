terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92"
    }
  }

  required_version = ">= 1.2"
}

provider "aws" {
  region = var.aws_region
}

# ----------------------
# REDE
# ----------------------

# VPC
resource "aws_vpc" "vpcDoMax" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "vpc-do-max"
  }
}

# Subnet pública
resource "aws_subnet" "subnetDoMax" {
  vpc_id                  = aws_vpc.vpcDoMax.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}a"

  tags = {
    Name = "subnet-do-max"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igwDoMax" {
  vpc_id = aws_vpc.vpcDoMax.id

  tags = {
    Name = "igw-do-max"
  }
}

# Route Table
resource "aws_route_table" "rtDoMax" {
  vpc_id = aws_vpc.vpcDoMax.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igwDoMax.id
  }

  tags = {
    Name = "rt-do-max"
  }
}

# Associação da Subnet à Route Table
resource "aws_route_table_association" "rtaDoMax" {
  subnet_id      = aws_subnet.subnetDoMax.id
  route_table_id = aws_route_table.rtDoMax.id
}

# ----------------------
# SEGURANÇA
# ----------------------
resource "aws_security_group" "sgDoMax" {
  name        = var.security_group_name
  description = "Security group do Max"
  vpc_id      = aws_vpc.vpcDoMax.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "App port"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg-do-max"
  }
}

# ----------------------
# COMPUTAÇÃO
# ----------------------
resource "aws_instance" "ec2DoMax" {
  ami                         = var.ami
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.subnetDoMax.id
  vpc_security_group_ids      = [aws_security_group.sgDoMax.id]
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              set -e

              # Atualizar pacotes
              yum update -y

              # Instalar dependências
              yum install -y git docker cronie lsof

              # Instalar docker-compose
              curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
              chmod +x /usr/local/bin/docker-compose

              # Iniciar e habilitar serviços
              for service in docker crond; do
                  systemctl enable $service
                  systemctl start $service
              done

              # Preparar app
              APP_DIR="/app/React-Vite-Spring-na-AWS"
              if [ ! -d "$APP_DIR" ]; then
                  git clone https://github.com/Max-Leal/React-Vite-Spring-na-AWS.git $APP_DIR
              fi

              cd $APP_DIR
              git pull origin main || true
              chmod +x deploy.sh

              # Executar primeiro deploy
              $APP_DIR/deploy.sh
              EOF

  tags = {
    Name = var.ec2_name
  }
}

# ----------------------
# VARIÁVEIS
# ----------------------
variable "ec2_name" {
  description = "name of the ec2 instance"
  type        = string
  default     = "ReactViteSpring-na-AWS"
}

variable "aws_region" {
  description = "Aws region"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "The EC2 instance's type."
  type        = string
  default     = "t3.micro"
}

variable "ami" {
  description = "The ami selected"
  type        = string
  default     = "ami-08982f1c5bf93d976" # Amazon Linux 2
}

variable "security_group_name" {
  description = "Security group name"
  type        = string
  default     = "ReactViteSpring"
}

# ----------------------
# OUTPUTS
# ----------------------
output "ec2_public_ip" {
  description = "IP público da instância"
  value       = aws_instance.ec2DoMax.public_ip
}

output "ec2_public_dns" {
  description = "DNS público da instância"
  value       = aws_instance.ec2DoMax.public_dns
}
