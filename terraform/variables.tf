# --- VARIÁVEIS ---
# Valores para estas variáveis serão fornecidos em um arquivo terraform.tfvars
variable "project_name" {
  description = "Nome do projeto para identificar os recursos"
  type        = string
  default     = "CloudReactViteSpringApp"
}

variable "domain_name" {
  description = "Seu nome de domínio registrado no Route 53"
  type        = string
}

variable "aws_key_pair_name" {
  description = "Nome do par de chaves SSH que VOCÊ JÁ CRIOU no console da AWS EC2"
  type        = string
}