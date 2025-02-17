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

import org.apache.flink.table.api.EnvironmentSettings;
import org.apache.flink.table.api.TableEnvironment;
import org.apache.flink.configuration.Configuration;


public class EcommerceAnalyticsJob {

	public static void main(String[] args) throws Exception {
		// Sets up the execution environment, which is the main entry point
		// to building Flink applications.
        EnvironmentSettings settings = EnvironmentSettings
                        .newInstance()
                        .inStreamingMode()
                        .build();
        TableEnvironment tableEnv = TableEnvironment.create(settings);


        String[] catalogs = tableEnv.listCatalogs();
        Arrays.stream(catalogs).forEach(System.out::println);
		Properties properties = new Properties();
        properties.setProperty("bootstrap.servers", "localhost:9092");
        properties.setProperty("group.id", "flink-ecommerce-group");

        tableEnv.executeSql("SHOW TABLES").print();
	}
}



