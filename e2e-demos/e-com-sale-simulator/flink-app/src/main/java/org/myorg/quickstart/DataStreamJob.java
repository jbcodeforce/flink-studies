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

import java.util.Properties;

import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.api.common.state.ValueState;
import org.apache.flink.api.common.state.ValueStateDescriptor;
import org.apache.flink.configuration.Configuration;
import org.apache.flink.streaming.api.functions.KeyedProcessFunction;
import org.apache.flink.util.Collector;


public class DataStreamJob {

	public static void main(String[] args) throws Exception {
		// Sets up the execution environment, which is the main entry point
		// to building Flink applications.
		final StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
		Properties properties = new Properties();
        properties.setProperty("bootstrap.servers", "localhost:9092");
        properties.setProperty("group.id", "flink-ecommerce-group");

        DataStream<EcommerceEvent> dataStream = env
            .addSource(new FlinkKafkaConsumer<>("ecommerce_events", new JSONDeserializationSchema<>(EcommerceEvent.class), properties))
            .map(new MapFunction<EcommerceEvent, EcommerceEvent>() {
                @Override
                public EcommerceEvent map(EcommerceEvent event) throws Exception {
                    return event;
                }
            });

        // Implement your processing logic here
        dataStream
            .keyBy((KeySelector<EcommerceEvent, String>) EcommerceEvent::getEventType)
            .process(new EcommerceEventProcessor())
            .print();

        env.execute("Flink Ecommerce Analytics");
	}
}

class EcommerceEvent {
    private String eventType;
    private String timestamp;
    // Add other fields as per the data generator
    
    // Getters and setters
	String getEventType() {
		return eventType;
	}
}

class EcommerceEventProcessor extends KeyedProcessFunction<String, EcommerceEvent, String>  {

	private ValueState<Integer> countState;

	@Override
    public void open(Configuration parameters) throws Exception {
        countState = getRuntimeContext().getState(new ValueStateDescriptor<>("count", Integer.class));
    }

    @Override
    public void processElement(EcommerceEvent event, Context context, Collector<String> out) throws Exception {
        // Update count
        Integer count = countState.value();
        if (count == null) {
            count = 0;
        }
        count++;
        countState.update(count);

        // Process based on event type
        switch (event.getEventType()) {
            case "user_action":
                processUserAction(event, count, out);
                break;
            case "purchase":
                processPurchase(event, count, out);
                break;
            case "inventory_update":
                processInventoryUpdate(event, count, out);
                break;
        }
    }

    private void processUserAction(EcommerceEvent event, int count, Collector<String> out) {
        out.collect("Processed user action #" + count + ": " + event.toString());
    }

    private void processPurchase(EcommerceEvent event, int count, Collector<String> out) {
        out.collect("Processed purchase #" + count + ": " + event.toString());
    }

    private void processInventoryUpdate(EcommerceEvent event, int count, Collector<String> out) {
        out.collect("Processed inventory update #" + count + ": " + event.toString());
    }
}

