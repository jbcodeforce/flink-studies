# Multi-stage build for Flink Table API application
# Use build platform for Maven build (native compilation)
FROM --platform=$BUILDPLATFORM maven:3.9-eclipse-temurin-11 AS build

WORKDIR /app

# Copy pom.xml first to leverage Docker layer caching
COPY pom.xml .

# Download dependencies
RUN mvn dependency:go-offline -B

# Copy source code
COPY src ./src

# Build the application
RUN mvn clean package -B -DskipTests

# Runtime image - use target platform for runtime
FROM confluentinc/cp-flink:1.20.2-cp1-java17-arm64

# Create application directory
USER root
RUN mkdir -p /opt/flink/usrlib && chown flink:flink /opt/flink/usrlib
USER flink

# Copy the built jar
COPY --from=build --chown=flink:flink /app/target/payment-claims-enrichment-1.0.0.jar /opt/flink/usrlib/

# Set environment variables
ENV FLINK_APP_JAR=/opt/flink/usrlib/payment-claims-enrichment-1.0.0.jar
ENV FLINK_MAIN_CLASS=com.example.PaymentClaimsEnrichment

# Default configuration can be overridden via environment variables
ENV KAFKA_BOOTSTRAP_SERVERS=kafka.confluent.svc.cluster.local:9071
ENV PAYMENT_EVENTS_TOPIC=payment-events
ENV ENRICHED_PAYMENTS_TOPIC=enriched-payments
ENV FAILED_PAYMENTS_TOPIC=failed-payments
ENV CLAIMDB_URL=jdbc:duckdb:http://claimdb:8080/database

# Expose common Flink ports
EXPOSE 8081 6123 6124 6125

# Default command - can be overridden in docker-compose or k8s
CMD ["bash", "-c", "/opt/flink/bin/flink run \
    --class $FLINK_MAIN_CLASS \
    --jobmanager localhost:8081 \
    $FLINK_APP_JAR"]
