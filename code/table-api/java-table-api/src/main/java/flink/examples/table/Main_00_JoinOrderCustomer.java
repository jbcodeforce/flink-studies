package flink.examples.table;

import io.confluent.flink.plugin.ConfluentSettings;

import org.apache.flink.table.api.EnvironmentSettings;
import org.apache.flink.table.api.Table;
import org.apache.flink.table.api.TableEnvironment;


import static org.apache.flink.table.api.Expressions.$;
import static org.apache.flink.table.api.Expressions.row;
import static org.apache.flink.table.api.Expressions.withAllColumns;

import org.apache.flink.table.api.DataTypes;

/**
 * Join records from Orders with some customers data created from this program. 
 */
public class Main_00_JoinOrderCustomer {

    private static Table buildMockCustomerTable( TableEnvironment env) {
        return
                env.fromValues(
                        DataTypes.ROW(
                                DataTypes.FIELD("customer_id", DataTypes.INT()),
                                DataTypes.FIELD("name", DataTypes.STRING()),
                                DataTypes.FIELD("email", DataTypes.STRING())),
                        row(3160, "Bob", "bob@corp.com"),
                        row(3107, "Alice", "alice.smith@example.org"),
                        row(3248, "Robert", "robert@someinc.com"));
    }

    public static void main(String[] args) {
        // ConfluentSettings.newBuilderFromResource("/cloud.properties")
        EnvironmentSettings settings = ConfluentSettings.fromGlobalVariables();

        TableEnvironment env = TableEnvironment.create(settings);
        env.useCatalog("examples");
        env.useDatabase("marketplace");

        Table customers = Main_00_JoinOrderCustomer.buildMockCustomerTable(env);
        Table orders = env.from("orders").select(withAllColumns());
        Table filteredOrders = orders.filter($("customer_id").in(3160, 3107, 3107));
        Table transformedOrders =
            filteredOrders
                    .addColumns($("price").round(0).cast(DataTypes.INT()).as("price_rounded"))
                    .renameColumns($("customer_id").as("o_customer_id"));
        Table joinedTable =
            customers
                    .join(transformedOrders, $("customer_id").isEqual($("o_customer_id")))
                    .dropColumns($("o_customer_id"));
        
        // The result shows a joined table with the following columns:
        // customer_id | name | email | order_id | product_id | price | price_rounded
        joinedTable.execute().print();
    }
}