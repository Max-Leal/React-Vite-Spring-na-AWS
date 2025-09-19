# Estágio de build
FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
# Configura a variável de ambiente para a URL da API durante o build
# Esta URL será usada quando o frontend for servido (por exemplo, pelo Nginx)
# Você pode ajustá-la para o nome do serviço do backend no docker-compose
ARG VITE_API_URL
ENV VITE_API_URL=${VITE_API_URL:-http://localhost:8080/api/products}
RUN npm run build

# Estágio de execução com Nginx para servir os arquivos estáticos
FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
# Remove a configuração padrão do Nginx
RUN rm /etc/nginx/conf.d/default.conf
# Adiciona uma configuração Nginx customizada para lidar com o React Router e proxy para a API
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]