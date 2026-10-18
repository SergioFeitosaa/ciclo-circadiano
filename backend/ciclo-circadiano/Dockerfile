# Build da aplicação Spring Boot com Java 21 e Maven Wrapper
FROM eclipse-temurin:21-jdk AS build
WORKDIR /app

COPY mvnw pom.xml ./
COPY .mvn .mvn
RUN chmod +x mvnw

COPY src src
RUN ./mvnw -B -DskipTests package

# Imagem de execução menor, sem JDK nem código-fonte
FROM eclipse-temurin:21-jre
WORKDIR /app

RUN useradd --system --uid 10001 --no-create-home appuser
COPY --from=build /app/target/*.jar /app/application.jar

USER 10001
EXPOSE 8080
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75.0", "-jar", "/app/application.jar"]
