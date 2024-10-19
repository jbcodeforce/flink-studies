package acme;

import org.apache.flink.table.api.*;

import java.math.BigDecimal;
import java.time.Duration;

import static org.apache.flink.table.api.Expressions.*;

/**
 * Example of service class implementing Table API queries
 */
public class OrderService {
    private final TableEnvironment env;
    private final String ordersTableName;

    public OrderService(
        TableEnvironment env,
        String ordersTableName
    ) {
        this.env = env;
        this.ordersTableName = ordersTableName;
    }

    public TableResult ordersOver50Dollars() {
        return env.from(ordersTableName)
            .select($("*"))
            .where($("price").isGreaterOrEqual(50))
            .execute();
    }

    public TableResult pricesWithTax(BigDecimal taxAmount) {
        return env.from(ordersTableName)
            .select(
                $("order_id"),
                $("price")
                    .cast(DataTypes.DECIMAL(10, 2))
                    .as("original_price"),
                $("price")
                    .cast(DataTypes.DECIMAL(10, 2))
                    .times(taxAmount)
                    .round(2)
                    .as("price_with_tax")
            ).execute();
    }
}