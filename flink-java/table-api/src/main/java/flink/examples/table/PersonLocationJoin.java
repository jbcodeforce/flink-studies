package flink.examples.table;

import org.apache.flink.table.api.Table;
import org.apache.flink.table.api.TableEnvironment;
import org.apache.flink.table.api.EnvironmentSettings;
import org.apache.flink.table.api.TableResult;

import org.apache.flink.api.java.utils.ParameterTool;

/*
 * Using files as input, 
 */
public class PersonLocationJoin {
    
    public static void main(String[] args) {
        TableEnvironment tEnv = TableEnvironment.create(EnvironmentSettings.newInstance().build());

        ParameterTool params = ParameterTool.fromArgs(args);

        tEnv.executeSql(
            "CREATE TABLE src_persons (" +
            "   id BIGINT," +
            "   name STRING," +
            "   join_date DATE" +
            ") WITH (" +
            "   'connector' = 'filesystem'," +
            "   'path' = 'file:///data/persons.txt'," +
            "   'format' = 'csv'," +
            // CSV Format Options
            "   'csv.field-delimiter' = ','," +
            "   'csv.ignore-parse-errors' = 'true'," +
            "   'csv.allow-comments' = 'true'," +
            "   'csv.ignore-first-line' = 'true'," +  // Skip header
            "   'csv.null-literal' = 'NULL'" +        // String representation of null values
            ")"
        );

        // Example 1: Simple SELECT
        Table result = tEnv.sqlQuery("SELECT * FROM src_persons");
        TableResult tableResult = result.execute();
        tableResult.print();
    }
    
}
