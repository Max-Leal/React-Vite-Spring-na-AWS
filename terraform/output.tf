# --- OUTPUTS ---
# Informações úteis que o Terraform exibirá no final
output "public_ip" {
  description = "IP público da instância EC2"
  value       = aws_instance.app_server.public_ip
}

output "ssh_command" {
  description = "Exemplo de comando para conectar via SSH"
  value       = format("ssh -i /caminho/para/sua/chave-privada.pem ec2-user@%s", aws_instance.app_server.public_ip)
}

output "app_url" {
  description = "URL da aplicação (pode levar alguns minutos para o DNS propagar)"
  value       = "http://${var.domain_name}"
}