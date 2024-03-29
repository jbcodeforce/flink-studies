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

FROM flink:latest

# Create CLI lib folder
COPY bin/* /opt/sql-client/
RUN mkdir -p /opt/sql-client/lib

# Download connector libraries

RUN wget -P /opt/sql-client/lib/ https://repo.maven.apache.org/maven2/org/apache/flink/flink-sql-connector-elasticsearch7_2.12/1.14.4/flink-sql-connector-elasticsearch7_2.12-1.14.4.jar; \
    wget -P /opt/sql-client/lib/ https://repo.maven.apache.org/maven2/org/apache/flink/flink-sql-connector-kafka_2.12/1.14.4/flink-sql-connector-kafka_2.12-1.14.4.jar; \
    wget -P /opt/sql-client/lib/ https://repo.maven.apache.org/maven2/org/apache/flink/flink-connector-jdbc_2.12/1.14.4/flink-connector-jdbc_2.12-1.14.4.jar; \
    wget -P /opt/sql-client/lib/ https://jdbc.postgresql.org/download/postgresql-42.3.3.jar; \
    wget -P /opt/sql-client/lib/ https://repo.maven.apache.org/maven2/org/apache/flink/flink-sql-avro-confluent-registry/1.14.4/flink-sql-avro-confluent-registry-1.14.4.jar; \
    wget -P /opt/sql-client/lib/ https://github.com/knaufk/flink-faker/releases/download/v0.4.1/flink-faker-0.4.1.jar;

# Copy configuration
COPY conf/* /opt/flink/conf/

WORKDIR /opt/sql-client
ENV SQL_CLIENT_HOME /opt/sql-client

COPY docker-entrypoint.sh /
ENTRYPOINT ["/docker-entrypoint.sh"]
