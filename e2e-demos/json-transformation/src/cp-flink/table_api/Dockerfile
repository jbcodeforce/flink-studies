FROM confluentinc/cp-flink:2.1.0-cp1-java21

# Create application directory
USER root
RUN mkdir -p /opt/flink/usrlib && chown flink:flink /opt/flink/usrlib
USER flink

# Copy the built jar
COPY target/rental-dsp-1.0.0.jar /opt/flink/usrlib/

# Set environment variables
ENV FLINK_APP_JAR=/opt/flink/usrlib/rental-dsp-1.0.0.jar
ENV FLINK_MAIN_CLASS=rental.demo.table.RentalEventsProcessing

# Default configuration can be overridden via environment variables
ENV KAFKA_BOOTSTRAP_SERVERS=kafka.confluent.svc.cluster.local:9071



# Expose common Flink ports
EXPOSE 8081 6123 6124 6125

# Default command - can be overridden in docker-compose or k8s
CMD ["bash", "-c", "/opt/flink/bin/flink run \
    --class $FLINK_MAIN_CLASS \
    --jobmanager localhost:8081 \
    $FLINK_APP_JAR"]
