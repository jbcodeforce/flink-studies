package org.acme;

import java.time.LocalDate;

import org.apache.flink.api.common.RuntimeExecutionMode;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.table.api.EnvironmentSettings;
import org.apache.flink.table.api.TableEnvironment;
import static org.apache.flink.table.api.Expressions.row;

public class LoadDataToPrint {
    
    public static void main(String[] args) throws Exception {
        StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
        env.setRuntimeMode(RuntimeExecutionMode.BATCH);
        env.fromData(ExampleData.CUSTOMERS)
        .executeAndCollect()
        .forEachRemaining(System.out::println);

        /**
         *  Customer(c_id=12, c_name=Alice, c_birthday=1984-03-12)
            Customer(c_id=32, c_name=Bob, c_birthday=1990-10-14)
            Customer(c_id=7, c_name=Kyle, c_birthday=1979-02-23)
         */

        TableEnvironment tableEnv = TableEnvironment.create(EnvironmentSettings.inStreamingMode());

        tableEnv.fromValues(
                row(12L, "Alice", LocalDate.of(1984, 3, 12)),
                row(32L, "Bob", LocalDate.of(1990, 10, 14)),
                row(7L, "Kyle", LocalDate.of(1979, 2, 23)))
            .as("c_id", "c_name", "c_birthday")
            .execute()
            .print();
        /**
         *  +----+----------------------+--------------------------------+------------+
            | op |                 c_id |                         c_name | c_birthday |
            +----+----------------------+--------------------------------+------------+
            | +I |                   12 |                          Alice | 1984-03-12 |
            | +I |                   32 |                            Bob | 1990-10-14 |
            | +I |                    7 |                           Kyle | 1979-02-23 |
            +----+----------------------+--------------------------------+------------+
         */
    }
}
