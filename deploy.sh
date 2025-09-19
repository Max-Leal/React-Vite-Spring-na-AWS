yum update
yum install -y git docker cronie lsof
yum install -y docker-compose-plugin

# make sure every necessary service is running
for service in docker crond; do
    systemctl start $service
    systemctl enable $service
done

# variables
APP_DIR="/app/React-Vite-Spring-na-AWS"
DEPLOY_SCRIPT_PATH="$APP_DIR/deploy.sh"

cd "$APP_DIR"

git reset --hard HEAD
git pull https://github.com/Max-Leal/React-Vite-Spring-na-AWS.git main

docker compose up --build -d

echo "Deploy/Update finished successfully."

(crontab -l 2>/dev/null | grep -v "/app/React-Vite-Spring-na-AWS/deploy.sh"; echo "*/5 * * * * /app/React-Vite-Spring-na-AWS/deploy.sh") | crontab -

echo "Cron job configured to run every 5 minutes."