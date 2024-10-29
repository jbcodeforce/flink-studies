package flink.examples.table;


public class Main_01_deduplication {

    public static void main(String[] args) {
        EnvironmentSettings settings = ConfluentSettings.fromGlobalVariables();

        TableEnvironment env = TableEnvironment.create(settings);
        env.useCatalog("examples");
        env.useDatabase("marketplace");

    }
}    
