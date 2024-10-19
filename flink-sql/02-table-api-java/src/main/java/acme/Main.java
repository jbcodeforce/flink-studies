package acme;


import io.confluent.flink.plugin.ConfluentSettings;
import org.apache.flink.table.api.EnvironmentSettings;
import org.apache.flink.table.api.TableEnvironment;

import java.io.File;
import java.math.BigDecimal;
import java.time.Duration;
import java.util.Arrays;


public class Main {

    public static void main(String[] args) {
        EnvironmentSettings settings = ConfluentSettings.fromResource("/cloud.properties");
        TableEnvironment env = TableEnvironment.create(settings);
        
        env.useCatalog("examples");
        env.useDatabase(settings.get("kafka.cluster.name"));
        /* Example of environment api */
        Arrays.stream(env.listTables()).forEach(System.out::println);

        /* define the data flow as a set of function call to service classes
         *  OrderService orders = new OrderService(
            env,
            "`examples`.`marketplace`.`orders`"
        );
         *  orders.ordersOver50Dollars();
         */
    }
}
