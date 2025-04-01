package flink.examples.table;

import io.confluent.flink.plugin.ConfluentSettings;
import org.apache.flink.table.api.Table;
import org.apache.flink.table.api.TableEnvironment;
import org.apache.flink.table.api.EnvironmentSettings;

public class Main_01_deduplication {

    public static void main(String[] args) {
        EnvironmentSettings settings = ConfluentSettings.fromGlobalVariables();

        TableEnvironment env = TableEnvironment.create(settings);
        env.useCatalog("examples");
        env.useDatabase("marketplace");

    }
}    
