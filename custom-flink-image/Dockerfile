###############################################################################
#  Licensed to the Apache Software Foundation (ASF) under one
#  or more contributor license agreements.  See the NOTICE file
#  distributed with this work for additional information
#  regarding copyright ownership.  The ASF licenses this file
#  to you under the Apache License, Version 2.0 (the
#  "License"); you may not use this file except in compliance
#  with the License.  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
# limitations under the License.
###############################################################################


###############################################################################
#SQL CLI - inspired by https://github.com/wuchong/flink-sql-demo/tree/v1.11-EN/sql-client
###############################################################################

FROM flink:1.19.1-scala_2.12-java11

# Download connector libraries  version verified 10/2024
RUN wget -P /opt/flink/lib/ https://repo.maven.apache.org/maven2/org/apache/flink/flink-sql-connector-elasticsearch7/3.0.1-1.17/flink-sql-connector-elasticsearch7-3.0.1-1.17.jar; \
    wget -P /opt/flink/lib/ https://repo.maven.apache.org/maven2/org/apache/flink/flink-sql-connector-kafka/3.2.0-1.19/flink-sql-connector-kafka-3.2.0-1.19.jar; \
    wget -P /opt/flink/lib/ https://repo.maven.apache.org/maven2/org/apache/flink/flink-connector-jdbc/3.2.0-1.19/flink-connector-jdbc-3.2.0-1.19.jar; \
    wget -P /opt/flink/lib/ https://repo.maven.apache.org/maven2/org/apache/flink/flink-connector-kafka/3.2.0-1.19/flink-connector-kafka-3.2.0-1.19.jar \
    wget -P /opt/flink/lib/ https://jdbc.postgresql.org/download/postgresql-42.7.4.jar; \
    wget -P /opt/flink/lib/ https://repo.maven.apache.org/maven2/org/apache/flink/flink-sql-avro-confluent-registry/1.19.1/flink-sql-avro-confluent-registry-1.19.1.jar; \
    wget -P /opt/flink/lib/ https://github.com/knaufk/flink-faker/releases/download/v0.5.3/flink-faker-0.5.3.jar; 



WORKDIR /opt/flink
ENV SQL_CLIENT_HOME=/opt/flink/opt/flink
COPY conf/config.yaml conf/config.yaml 
COPY docker-entrypoint.sh /
ENTRYPOINT ["/docker-entrypoint.sh"]
