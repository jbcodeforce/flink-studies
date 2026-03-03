# Build stage (use full version tag; alpine variant may be unavailable)
FROM maven:3.9.9-eclipse-temurin-17 AS builder
WORKDIR /build

COPY pom.xml .
RUN mvn dependency:go-offline -B

COPY src ./src
RUN mvn package -DskipTests -q

# Runtime stage
FROM eclipse-temurin:17-jre
WORKDIR /app

COPY --from=builder /build/target/perf-data-generator-*.jar app.jar

ENTRYPOINT ["java", "-jar", "app.jar"]
