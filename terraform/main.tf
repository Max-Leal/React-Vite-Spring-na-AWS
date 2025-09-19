# Configura o provedor AWS
provider "aws" {
  region = "us-east-1" # Escolha sua região preferida
}

# Variáveis (opcional, mas boa prática)
variable "project_name" {
  description = "Nome do projeto"
  type        = string
  default     = "CloudReactViteSpringApp"
}

variable "domain_name" {
  description = "Seu nome de domínio para Route 53 (se aplicável)"
  type        = string
  default     = "example.com" # MUDE PARA SEU DOMÍNIO REAL
}

# 1. VPC
resource "aws_vpc" "app_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# 2. Subnet Pública
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.app_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true # Para a EC2 ter um IP público
  availability_zone       = "us-east-1a" # Mude para uma AZ na sua região
  tags = {
    Name = "${var.project_name}-public-subnet"
  }
}

# 3. Internet Gateway (para a VPC se comunicar com a internet)
resource "aws_internet_gateway" "app_igw" {
  vpc_id = aws_vpc.app_vpc.id
  tags = {
    Name = "${var.project_name}-igw"
  }
}

# 4. Tabela de Rotas
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.app_vpc.id
  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# Rota para a internet
resource "aws_route" "public_internet_route" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.app_igw.id
}

# Associação da Tabela de Rotas com a Subnet
resource "aws_route_table_association" "public_rt_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# 5. Security Group (Firewall para a EC2)
resource "aws_security_group" "app_sg" {
  name        = "${var.project_name}-sg"
  description = "Security group for Spring Boot and React/Vite app"
  vpc_id      = aws_vpc.app_vpc.id

  # Regra de entrada para SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Acesso de qualquer IP (alterar em produção)
  }

  # Regra de entrada para o frontend (HTTP)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Regra de entrada para o backend (HTTP) - se você quiser acessar diretamente
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Acesso de qualquer IP (alterar em produção)
  }

  # Regras de saída (permite toda a saída)
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

# 6. Chave SSH (se você ainda não tem uma e quer que o Terraform crie)
# Remova ou comente esta seção se você já tem uma chave e vai referenciá-la.
resource "tls_private_key" "app_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "app_key_pair" {
  key_name   = "${var.project_name}-key"
  public_key = tls_private_key.app_key.public_key_openssh
}

resource "local_file" "ssh_key" {
  content  = tls_private_key.app_key.private_key_pem
  filename = "${var.project_name}-key.pem"
  file_permission = "0400" # Permissões restritas para chave privada
}

# 7. EC2 Instance com UserData para Docker e Docker Compose
resource "aws_instance" "app_server" {
  ami           = "ami-053b0d53c279acc90" # Amazon Linux 2023 - us-east-1 (mude se usar outra região)
  instance_type = "t3.small"             # t2.micro pode ser muito pequena para ambos containers
  key_name      = aws_key_pair.app_key_pair.key_name # Ou sua chave existente
  subnet_id     = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  associate_public_ip_address = true # Atribuir IP público

  # UserData para instalar Docker, Docker Compose e puxar o repositório
  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install -y docker git
              sudo systemctl start docker
              sudo systemctl enable docker
              sudo usermod -aG docker ec2-user

              # Instalar Docker Compose v2 (plugin do Docker)
              sudo yum install -y docker-compose-plugin

              # Crie um diretório para o projeto e clone o repositório
              # ATENÇÃO: SUBSTITUA COM A URL DO SEU REPOSITÓRIO GITHUB/BITBUCKET
              sudo su - ec2-user -c "git clone https://github.com/Max-Leal/React-Vite-Spring-na-AWS.git /home/ec2-user/${var.project_name}"

              # Navegue até o diretório e inicie o Docker Compose
              sudo su - ec2-user -c "cd /home/ec2-user/${var.project_name} && docker compose up --build -d"
              EOF

  tags = {
    Name = "${var.project_name}-server"
  }
}

# 8. Route 53 - Zona Hospedada (se já tiver)
# Se você já tem uma Hosted Zone para o seu domínio, use um data source para referenciá-la
data "aws_route53_zone" "selected" {
  name         = var.domain_name
  private_zone = false
}

# Registro A para apontar o domínio para o IP público da EC2
resource "aws_route53_record" "app_record" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = var.domain_name
  type    = "A"
  ttl     = "300"
  records = [aws_instance.app_server.public_ip]
}

# 9. Outputs (para obter informações úteis após a aplicação)
output "public_ip" {
  description = "IP público da instância EC2"
  value       = aws_instance.app_server.public_ip
}

output "ssh_command" {
  description = "Comando para SSH na instância"
  value       = "ssh -i ${var.project_name}-key.pem ec2-user@${aws_instance.app_server.public_ip}"
}

output "app_url" {
  description = "URL da aplicação (frontend)"
  value       = "http://${var.domain_name}"
}