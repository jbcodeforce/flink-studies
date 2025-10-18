package j9r;
import org.apache.flink.configuration.Configuration;
import org.apache.flink.configuration.RestOptions;
import org.apache.flink.configuration.WebOptions;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.table.api.DataTypes;
import org.apache.flink.table.api.Schema;
import org.apache.flink.table.api.Table;
import org.apache.flink.table.api.bridge.java.StreamTableEnvironment;
import org.apache.flink.types.Row;
import static org.apache.flink.table.api.Expressions.*;

public class SimpleTableTest {

    public static void main(String[] args) throws Exception {
        
        StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();
        StreamTableEnvironment tableEnv = StreamTableEnvironment.create(env);

        // 4. Create a Table from in-memory values
        Table persons = tableEnv.fromValues(
                DataTypes.ROW(
                    DataTypes.FIELD("id", DataTypes.DECIMAL(10, 2)),
                    DataTypes.FIELD("name", DataTypes.STRING())
                ),
                Row.of(1, "Alice"),
                Row.of(2, "Bob"),
                Row.of(3, "Charlie"),
                Row.of(4, "David"),
                Row.of(5, "Eve")
        );

        // 5. Define a simple transformation (filter names starting with 'C' or 'D')
        final Table resultTable = persons
            .filter($("name").like("C%")
                .or($("name").like("D%")))
            .select($("id"), $("name"));

        // 6. Convert Table back to DataStream and print
        System.out.println("Executing Flink Table API job...");
        tableEnv.toDataStream(resultTable, Row.class).print();

        // 7. Execute the job and keep it running
        env.execute("Simple Table API Example");
    }
}