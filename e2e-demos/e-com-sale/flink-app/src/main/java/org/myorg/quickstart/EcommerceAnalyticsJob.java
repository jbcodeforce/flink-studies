/*
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package org.myorg.quickstart;

import java.util.Arrays;
import java.util.Properties;

import static org.apache.flink.table.api.Expressions.*;
import org.apache.flink.table.api.EnvironmentSettings;
import org.apache.flink.table.api.TableEnvironment;
import org.apache.flink.configuration.Configuration;
import org.apache.flink.table.api.DataTypes;
import org.apache.flink.table.api.Schema;
import org.apache.flink.table.api.Table;
import org.apache.flink.table.api.TableDescriptor;
import org.apache.flink.table.api.FormatDescriptor;

/**
 * Demonstrate a join between two streams:
 * - purchase done by a user and product description
 */
public class EcommerceAnalyticsJob {
    // keys for env variables
    public static final String FLINK_DB_NAME="FLINK_DB_NAME";
    public static final String KAFKA_TX_TOPIC="KAFKA_TX_TOPIC";
    public static final String PURCHASE_TABLE_NAME="PurchaseTable";

	public static void main(String[] args) throws Exception {
		// Sets up the execution environment, which is the main entry point
		// to building Flink applications.
        EnvironmentSettings settings = EnvironmentSettings
                        .newInstance()
                        .inStreamingMode()
                        .build();
        TableEnvironment tableEnv = TableEnvironment.create(settings);
        String PURCHASE_SOURCE=System.getenv(KAFKA_TX_TOPIC);
        TableDescriptor table_descriptor = purchase_stream_source(PURCHASE_SOURCE);
        // Registers the given TableDescriptor as a catalog table. The first parameter needs to be camelcase only and represent the name of the table in the catalog
        tableEnv.createTable(PURCHASE_TABLE_NAME, table_descriptor);

        Table transactionsTable = tableEnv.from(PURCHASE_TABLE_NAME).select(withAllColumns());
        transactionsTable.printSchema();
        transactionsTable.execute().print();
	} // main

    /**
     * Return a template for creating a CatalogTable instance.
     */
    public static TableDescriptor purchase_stream_source(String topic_name) {

        return TableDescriptor.forConnector("kafka")
                    .schema(
                        Schema.newBuilder()
                            .column("event_type", DataTypes.STRING())
                            .column("purchase_id", DataTypes.STRING())
                            .column("timestamp", DataTypes.STRING())
                            .column("user_id", DataTypes.STRING())
                            .column("product", DataTypes.STRING())
                            .column("quantity", DataTypes.BIGINT())
                            .column("price", DataTypes.BIGINT())
                        .build()
                        )
                    .format("json")
                    .option("topic", topic_name)
                    .option("properties.group.id", "appGroup")
                    .option("scan.startup.mode", "earliest-offset")
                    .option("properties.bootstrap.servers", System.getenv("KAFKA_BOOTSTRAP_SERVERS"))
                    .option("properties.security.protocol", System.getenv("KAFKA_SECURITY_PROTOCOL"))
                    .option("properties.sasl.mechanism", System.getenv("KAFKA_SASL_MECHANISM"))
                    .build();

    }

}



