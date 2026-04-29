# Apache Flink 2.2 with Kafka SQL connector (2.0 line; fat JAR for Kafka source in Table/SQL).
# See https://nightlies.apache.org/flink/flink-docs-release-2.2/docs/connectors/table/kafka/
FROM apache/flink:2.2.0-java11

ARG KAFKA_CONNECTOR_VERSION=4.0.1-2.0
ADD --chown=flink:flink \
  https://repo1.maven.org/maven2/org/apache/flink/flink-sql-connector-kafka/${KAFKA_CONNECTOR_VERSION}/flink-sql-connector-kafka-${KAFKA_CONNECTOR_VERSION}.jar \
  /opt/flink/lib/

# Used by jobmanager healthcheck in docker-compose (base image is minimal)
USER root
RUN apt-get update && apt-get install -y --no-install-recommends curl \
  && rm -rf /var/lib/apt/lists/*
USER flink
