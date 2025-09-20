#!/bin/bash

# Atualiza pacotes e instala dependências
yum update -y
yum install -y git docker cronie lsof

# Instala Docker Compose (última versão)
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Garante que os serviços estão ativos
for service in docker crond; do
    systemctl start $service
    systemctl enable $service
done

# Variáveis
APP_DIR="/app/React-Vite-Spring-na-AWS"
REPO_URL="https://github.com/Max-Leal/React-Vite-Spring-na-AWS.git"
DEPLOY_SCRIPT_PATH="$APP_DIR/deploy.sh"

# Cria diretório base
mkdir -p /app
cd /app

# Clona o repositório caso não exista
if [ ! -d "$APP_DIR/.git" ]; then
    echo "Repositório não encontrado. Clonando..."
    git clone "$REPO_URL"
else
    echo "Repositório encontrado. Atualizando..."
    cd "$APP_DIR"
    git reset --hard HEAD
    git pull origin main
fi

# Executa o docker-compose
cd "$APP_DIR"
docker-compose up --build -d

echo "Deploy/Update finished successfully."

# Configura cron job para rodar o deploy a cada 5 minutos
(crontab -l 2>/dev/null | grep -v "$DEPLOY_SCRIPT_PATH"; echo "*/5 * * * * $DEPLOY_SCRIPT_PATH") | crontab -

echo "Cron job configurado para rodar a cada 5 minutos."
