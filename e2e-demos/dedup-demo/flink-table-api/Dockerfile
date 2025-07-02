# Use the official Flink image as base
FROM flink:1.19.2-scala_2.12-java17

# Set working directory
WORKDIR /opt/flink

# Copy the application JAR to the Flink lib directory
COPY target/flink-product-dedup-job-1.0.0.jar /opt/flink/usrlib/

# Copy log4j configuration (optional)
COPY src/main/resources/log4j2.properties /opt/flink/conf/

# Create a non-root user for security
RUN groupadd --gid 1001 flink-grp && \
    useradd --uid 1001  --gid flink-grp flink-app

# -D: Don't assign a password
# -s /bin/sh: Set shell to sh (lightweight)
# -G: Assign to supplementary group

# Change ownership of the necessary directories
RUN chown -R flink-app:flink-grp /opt/flink

# Switch to non-root user
USER flink-app

# Set the main class as environment variable (used by Flink job submission)
ENV FLINK_MAIN_CLASS=com.jbcodeforce.dedup.ProductDeduplicationJob

# Default arguments for the job
ENV KAFKA_BOOTSTRAP_SERVERS=kafka:9092
ENV INPUT_TOPIC=products
ENV OUTPUT_TOPIC=src_products
ENV CONSUMER_GROUP=flink-dedup-consumer

# Expose Flink web UI port (if running standalone)
EXPOSE 8081

# Health check (optional)
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8081/overview || exit 1

# Default command - this will be overridden by Kubernetes deployment
CMD ["help"] 