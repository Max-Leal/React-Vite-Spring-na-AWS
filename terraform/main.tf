# Configura o provedor AWS
provider "aws" {
  region = "us-east-1"
}

# --- PERMISSÕES (IAM) PARA O SESSION MANAGER ---
# 1. Cria o "Role" que a EC2 irá "assumir"
resource "aws_iam_role" "ec2_ssm_role" {
  name = "${var.project_name}-ssm-role"

  # Permite que o serviço EC2 assuma este role
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# 2. Anexa a política gerenciada pela AWS que dá as permissões para o Session Manager
resource "aws_iam_policy_attachment" "ssm_policy_attachment" {
  name       = "ssm-policy-attachment"
  roles      = [aws_iam_role.ec2_ssm_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# 3. Cria o "Instance Profile", que é o contêiner para o Role que será anexado à EC2
resource "aws_iam_instance_profile" "ec2_ssm_instance_profile" {
  name = "${var.project_name}-ssm-instance-profile"
  role = aws_iam_role.ec2_ssm_role.name
}


# --- REDE (VPC, Subnet, etc.) ---
# 1. VPC: Ambiente de rede isolado
resource "aws_vpc" "app_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# 2. Subnet Pública: Onde a EC2 vai morar e ter acesso à internet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.app_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.project_name}-public-subnet"
  }
}

# 3. Internet Gateway: A "porta" da VPC para a internet
resource "aws_internet_gateway" "app_igw" {
  vpc_id = aws_vpc.app_vpc.id
  tags = {
    Name = "${var.project_name}-igw"
  }
}

# 4. Tabela de Rotas: O "GPS" da rede, direcionando tráfego para a internet
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.app_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.app_igw.id
  }
  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# Associação da Tabela de Rotas com a Subnet
resource "aws_route_table_association" "public_rt_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}


# --- SEGURANÇA ---
# 5. Security Group: O firewall da EC2
resource "aws_security_group" "app_sg" {
  name        = "${var.project_name}-sg"
  description = "Firewall for the application"
  vpc_id      = aws_vpc.app_vpc.id

  # Acesso HTTP para o frontend React
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }

  # Regra de saída para permitir que a instância acesse a internet (git, yum, etc)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.project_name}-sg"
  }
}


# --- COMPUTAÇÃO ---
# 6. EC2 Instance: O servidor onde a aplicação vai rodar
resource "aws_instance" "app_server" {
  ami           = "ami-053b0d53c279acc90" # Amazon Linux 2023 - us-east-1
  instance_type = "t3.micro"
  
  # Anexa o Role do IAM para permitir acesso via Session Manager
  iam_instance_profile = aws_iam_instance_profile.ec2_ssm_instance_profile.name
  
  subnet_id     = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  
  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install -y docker git
              sudo systemctl start docker
              sudo systemctl enable docker
              sudo usermod -aG docker ec2-user
              sudo yum install -y docker-compose-plugin
              sudo su - ec2-user -c "git clone https://github.com/Max-Leal/React-Vite-Spring-na-AWS.git /home/ec2-user/${var.project_name}"
              sudo su - ec2-user -c "cd /home/ec2-user/${var.project_name} && docker compose up --build -d"
              EOF
  tags = {
    Name = "${var.project_name}-server"
  }
}


# --- DNS ---
# 7. Route 53: CRIA a Zona Hospedada para o seu domínio
resource "aws_route53_zone" "app_zone" {
  name = var.domain_name
}

# CRIA o registro 'A' dentro da Zona Hospedada criada acima
resource "aws_route53_record" "app_record" {
  zone_id = aws_route53_zone.app_zone.zone_id
  name    = var.domain_name
  type    = "A"
  ttl     = 300
  records = [aws_instance.app_server.public_ip]
}


# --- VARIÁVEIS ---
variable "project_name" {
  description = "Nome do projeto para identificar os recursos"
  type        = string
  default     = "CloudReactViteSpringApp"
}

variable "domain_name" {
  description = "Seu nome de domínio (ex: seudominio.com)"
  type        = string
  default     = "CloudReactViteSpringApp-produtos-max.com"
}


# --- OUTPUTS ---
output "public_ip" {
  description = "IP público da instância EC2. Use para verificar se o servidor está respondendo."
  value       = aws_instance.app_server.public_ip
}

output "app_url" {
  description = "URL final da aplicação. Pode levar alguns minutos para o DNS propagar."
  value       = "http://${var.domain_name}"
}

output "route53_name_servers" {
  description = "IMPORTANTE: Configure estes Servidores de Nome (NS) no painel do seu provedor de domínio."
  value       = aws_route53_zone.app_zone.name_servers
}