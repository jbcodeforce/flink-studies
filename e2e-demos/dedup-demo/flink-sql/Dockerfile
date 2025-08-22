################################################################################
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
################################################################################

# FROM flink:scala_2.12-java17
FROM confluentinc/cp-flink:1.20.2-cp1-java17-arm64

RUN mkdir /opt/flink/usrlib; mkdir /opt/flink/usrlib/sql-scripts
ADD flink-sql-runner.jar /opt/flink/usrlib/sql-runner.jar
ADD flink-deduplication.sql /opt/flink/usrlib/sql-scripts
