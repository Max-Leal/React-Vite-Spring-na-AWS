# Configura o provedor AWS
provider "aws" {
  region = "us-east-1" # Escolha sua região preferida
}

# --- REDE ---
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
  map_public_ip_on_launch = true # Essencial para a EC2 ter um IP público
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
    cidr_block = "0.0.0.0/0" # Para todo o tráfego de internet
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
  description = "Firewall para a aplicação"
  vpc_id      = aws_vpc.app_vpc.id

  # Libera acesso SSH (porta 22) para que você possa conectar
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # ATENÇÃO: Em produção, restrinja para seu IP
  }

  # Libera acesso HTTP (porta 80) para o frontend React
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Permite que a instância acesse a internet (para o git pull, yum update, etc)
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
  # AMI do Amazon Linux 2023 para us-east-1. Verifique o ID se usar outra região.
  ami           = "ami-053b0d53c279acc90"
  # t2.micro é a opção mais barata e elegível para o Free Tier da AWS.
  # Pode ser lenta se a aplicação crescer.
  instance_type = "t3.micro"
  # Usa a chave que você já criou na AWS
  key_name      = var.aws_key_pair_name
  subnet_id     = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.app_sg.id]

  # Script que roda na criação da máquina para instalar tudo e iniciar a aplicação
  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install -y docker git
              sudo systemctl start docker
              sudo systemctl enable docker
              sudo usermod -aG docker ec2-user

              sudo yum install -y docker-compose-plugin

              # Clona o repositório como o usuário ec2-user
              sudo su - ec2-user -c "git clone https://github.com/Max-Leal/React-Vite-Spring-na-AWS.git /home/ec2-user/${var.project_name}"

              # Inicia o docker-compose como o usuário ec2-user
              sudo su - ec2-user -c "cd /home/ec2-user/${var.project_name} && docker compose up --build -d"
              EOF

  tags = {
    Name = "${var.project_name}-server"
  }
}

# --- DNS ---
# 7. Route 53: Aponta seu domínio para o IP da EC2
data "aws_route53_zone" "selected" {
  name         = var.domain_name
  private_zone = false
}

resource "aws_route53_record" "app_record" {
  zone_id = data.aws_route53_zone.selected.zone_id
  # Aponta o domínio raiz. Use "www" se preferir www.seudominio.com
  name    = var.domain_name
  type    = "A"
  ttl     = 300
  records = [aws_instance.app_server.public_ip]
}