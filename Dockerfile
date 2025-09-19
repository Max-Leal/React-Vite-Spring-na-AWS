# Estágio de build
FROM openjdk:21-jdk-slim AS build
WORKDIR /app

# --- INÍCIO DA CORREÇÃO ---
# Copia os arquivos do Maven Wrapper para dentro do container
COPY .mvn/ .mvn
COPY mvnw .
# Garante que o script mvnw seja executável dentro do container
RUN chmod +x ./mvnw
# --- FIM DA CORREÇÃO ---

# Copia o pom.xml primeiro para aproveitar o cache do Docker
# Se as dependências não mudarem, o Docker não precisará baixá-las novamente
COPY pom.xml .
RUN ./mvnw dependency:go-offline

# Agora copia o restante do código fonte
COPY src ./src

# Finalmente, constrói o projeto
RUN ./mvnw clean package -DskipTests

# Estágio de execução
FROM openjdk:21-jdk-slim
WORKDIR /app
# Copia o JAR do estágio de build
COPY --from=build /app/target/*.jar app.jar
# Expõe a porta que o Spring Boot usa
EXPOSE 8080
# Comando para rodar a aplicação Spring Boot
ENTRYPOINT ["java", "-jar", "app.jar"]