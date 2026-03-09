package flink.studies.e2e.cdc;

import io.confluent.flink.plugin.ConfluentSettings;
import org.apache.flink.table.api.EnvironmentSettings;
import org.apache.flink.table.api.StatementSet;
import org.apache.flink.table.api.Table;
import org.apache.flink.table.api.TableEnvironment;

/**
 * Single Flink Table API job: raw Debezium Kafka topics → silver tables → dimension (dim_account)
 * and fact (fct_transactions). Uses a StatementSet to run all four pipelines in one job.
 *
 * <p>Expects Confluent Cloud (or equivalent) config via environment or resource. Set
 * FLINK_ENV_NAME and FLINK_DATABASE_NAME (or equivalent) for catalog/database. Raw tables
 * (raw_accounts, raw_transactions) must exist and be populated separately; this job creates
 * silver/dim/fact tables and runs the pipelines.
 */
public final class CdcToSilverTableJob {

    private static final String DDL_RAW_ACCOUNTS =
            "CREATE TABLE IF NOT EXISTS raw_accounts ("
                    + "`key` VARBINARY(2147483647),"
                    + "`source` ROW<ts_ms BIGINT>,"
                    + "`before` ROW<account_id STRING, account_name STRING, region STRING, created_at STRING>,"
                    + "`after` ROW<account_id STRING, account_name STRING, region STRING, created_at STRING>,"
                    + "op STRING"
                    + ") DISTRIBUTED BY HASH(`key`) INTO 1 BUCKETS "
                    + "WITH ("
                    + "'changelog.mode' = 'append',"
                    + "'key.avro-registry.schema-context' = '.flink-dev',"
                    + "'value.avro-registry.schema-context' = '.flink-dev',"
                    + "'key.format' = 'avro-registry',"
                    + "'value.format' = 'avro-registry',"
                    + "'kafka.retention.time' = '0',"
                    + "'scan.bounded.mode' = 'unbounded',"
                    + "'scan.startup.mode' = 'earliest-offset',"
                    + "'value.fields-include' = 'all'"
                    + ")";

    private static final String DDL_RAW_TRANSACTIONS =
            "CREATE TABLE IF NOT EXISTS raw_transactions ("
                    + "`key` VARBINARY(2147483647),"
                    + "`source` ROW<ts_ms BIGINT>,"
                    + "`before` ROW<txn_id STRING, account_id STRING, amount DECIMAL(10, 2), currency STRING, ts STRING, status STRING>,"
                    + "`after` ROW<txn_id STRING, account_id STRING, amount DECIMAL(10, 2), currency STRING, ts STRING, status STRING>,"
                    + "op STRING"
                    + ") DISTRIBUTED BY HASH(`key`) INTO 1 BUCKETS "
                    + "WITH ("
                    + "'changelog.mode' = 'append',"
                    + "'key.avro-registry.schema-context' = '.flink-dev',"
                    + "'value.avro-registry.schema-context' = '.flink-dev',"
                    + "'key.format' = 'avro-registry',"
                    + "'value.format' = 'avro-registry',"
                    + "'kafka.retention.time' = '0',"
                    + "'scan.bounded.mode' = 'unbounded',"
                    + "'scan.startup.mode' = 'earliest-offset',"
                    + "'value.fields-include' = 'all'"
                    + ")";

    private static final String DDL_SRC_ACCOUNTS =
            "CREATE TABLE IF NOT EXISTS src_accounts ("
                    + "account_id STRING,"
                    + "account_name STRING,"
                    + "region STRING,"
                    + "created_at STRING,"
                    + "src_op STRING,"
                    + "is_deleted BOOLEAN,"
                    + "src_timestamp TIMESTAMP_LTZ(3),"
                    + "WATERMARK FOR src_timestamp AS src_timestamp - INTERVAL '5' SECOND,"
                    + "PRIMARY KEY (account_id) NOT ENFORCED"
                    + ") DISTRIBUTED BY HASH(account_id) INTO 1 BUCKETS "
                    + "WITH ("
                    + "'changelog.mode' = 'upsert',"
                    + "'key.avro-registry.schema-context' = '.flink-dev',"
                    + "'value.avro-registry.schema-context' = '.flink-dev',"
                    + "'key.format' = 'avro-registry',"
                    + "'value.format' = 'avro-registry',"
                    + "'kafka.retention.time' = '0',"
                    + "'kafka.producer.compression.type' = 'snappy',"
                    + "'scan.bounded.mode' = 'unbounded',"
                    + "'scan.startup.mode' = 'earliest-offset',"
                    + "'value.fields-include' = 'all'"
                    + ")";

    private static final String DDL_SRC_TRANSACTIONS =
            "CREATE TABLE IF NOT EXISTS src_transactions ("
                    + "txn_id STRING,"
                    + "account_id STRING,"
                    + "amount DECIMAL(10, 2),"
                    + "currency STRING,"
                    + "`timestamp` TIMESTAMP_LTZ(3),"
                    + "status STRING,"
                    + "WATERMARK FOR `timestamp` AS `timestamp` - INTERVAL '5' SECOND,"
                    + "PRIMARY KEY (txn_id) NOT ENFORCED"
                    + ") DISTRIBUTED BY HASH(txn_id) INTO 1 BUCKETS "
                    + "WITH ("
                    + "'changelog.mode' = 'upsert',"
                    + "'key.avro-registry.schema-context' = '.flink-dev',"
                    + "'value.avro-registry.schema-context' = '.flink-dev',"
                    + "'key.format' = 'avro-registry',"
                    + "'value.format' = 'avro-registry',"
                    + "'kafka.retention.time' = '0',"
                    + "'kafka.producer.compression.type' = 'snappy',"
                    + "'scan.bounded.mode' = 'unbounded',"
                    + "'scan.startup.mode' = 'earliest-offset',"
                    + "'value.fields-include' = 'all'"
                    + ")";

    private static final String DDL_DIM_ACCOUNT =
            "CREATE TABLE IF NOT EXISTS dim_account ("
                    + "account_id STRING,"
                    + "account_name STRING,"
                    + "region STRING,"
                    + "created_at STRING,"
                    + "src_op STRING,"
                    + "is_deleted BOOLEAN,"
                    + "src_timestamp TIMESTAMP_LTZ(3),"
                    + "WATERMARK FOR src_timestamp AS src_timestamp - INTERVAL '5' SECOND,"
                    + "PRIMARY KEY (account_id) NOT ENFORCED"
                    + ") DISTRIBUTED BY HASH(account_id) INTO 1 BUCKETS "
                    + "WITH ("
                    + "'changelog.mode' = 'upsert',"
                    + "'key.avro-registry.schema-context' = '.flink-dev',"
                    + "'value.avro-registry.schema-context' = '.flink-dev',"
                    + "'key.format' = 'avro-registry',"
                    + "'value.format' = 'avro-registry',"
                    + "'kafka.retention.time' = '0',"
                    + "'kafka.producer.compression.type' = 'snappy',"
                    + "'scan.bounded.mode' = 'unbounded',"
                    + "'scan.startup.mode' = 'earliest-offset',"
                    + "'value.fields-include' = 'all'"
                    + ")";

    private static final String DDL_FCT_TRANSACTIONS =
            "CREATE TABLE IF NOT EXISTS fct_transactions ("
                    + "txn_id STRING,"
                    + "account_id STRING,"
                    + "amount DECIMAL(10, 2),"
                    + "currency STRING,"
                    + "`timestamp` TIMESTAMP_LTZ(3),"
                    + "status STRING,"
                    + "WATERMARK FOR `timestamp` AS `timestamp` - INTERVAL '5' SECOND,"
                    + "PRIMARY KEY (txn_id) NOT ENFORCED"
                    + ") DISTRIBUTED BY HASH(txn_id) INTO 1 BUCKETS "
                    + "WITH ("
                    + "'changelog.mode' = 'upsert',"
                    + "'key.avro-registry.schema-context' = '.flink-dev',"
                    + "'value.avro-registry.schema-context' = '.flink-dev',"
                    + "'key.format' = 'avro-registry',"
                    + "'value.format' = 'avro-registry',"
                    + "'kafka.retention.time' = '0',"
                    + "'kafka.producer.compression.type' = 'snappy',"
                    + "'scan.bounded.mode' = 'unbounded',"
                    + "'scan.startup.mode' = 'earliest-offset',"
                    + "'value.fields-include' = 'all'"
                    + ")";

    private static final String SELECT_RAW_TO_SRC_ACCOUNTS =
            "SELECT "
                    + "COALESCE(IF(op = 'd', `before`.account_id, `after`.account_id), '') AS account_id,"
                    + "COALESCE(IF(op = 'd', `before`.account_name, `after`.account_name), '') AS account_name,"
                    + "COALESCE(IF(op = 'd', `before`.region, `after`.region), '') AS region,"
                    + "COALESCE(IF(op = 'd', `before`.created_at, `after`.created_at), '') AS created_at,"
                    + "op AS src_op,"
                    + "(op = 'd') AS is_deleted,"
                    + "TO_TIMESTAMP_LTZ(`source`.ts_ms, 3) AS src_timestamp "
                    + "FROM raw_accounts WHERE `source`.ts_ms IS NOT NULL";

    private static final String SELECT_RAW_TO_SRC_TRANSACTIONS =
            "SELECT "
                    + "COALESCE(IF(op = 'd', `before`.txn_id, `after`.txn_id), '') AS txn_id,"
                    + "COALESCE(IF(op = 'd', `before`.account_id, `after`.account_id), '') AS account_id,"
                    + "COALESCE(IF(op = 'd', `before`.amount, `after`.amount), 0) AS amount,"
                    + "COALESCE(IF(op = 'd', `before`.currency, `after`.currency), '') AS currency,"
                    + "TO_TIMESTAMP_LTZ(`source`.ts_ms, 3) AS `timestamp`,"
                    + "COALESCE(IF(op = 'd', `before`.status, `after`.status), '') AS status "
                    + "FROM raw_transactions WHERE `source`.ts_ms IS NOT NULL";

    public static void main(String[] args) {
        EnvironmentSettings settings = ConfluentSettings.fromGlobalVariables();
        TableEnvironment env = TableEnvironment.create(settings);

        String catalog = System.getenv("FLINK_ENV_NAME");
        String database = System.getenv("FLINK_DATABASE_NAME");
        if (catalog != null && !catalog.isEmpty()) {
            env.useCatalog(catalog);
        }
        if (database != null && !database.isEmpty()) {
            env.useDatabase(database);
        }

        env.executeSql(DDL_RAW_ACCOUNTS);
        env.executeSql(DDL_RAW_TRANSACTIONS);
        env.executeSql(DDL_SRC_ACCOUNTS);
        env.executeSql(DDL_SRC_TRANSACTIONS);
        env.executeSql(DDL_DIM_ACCOUNT);
        env.executeSql(DDL_FCT_TRANSACTIONS);

        Table rawToSrcAccounts = env.sqlQuery(SELECT_RAW_TO_SRC_ACCOUNTS);
        Table rawToSrcTransactions = env.sqlQuery(SELECT_RAW_TO_SRC_TRANSACTIONS);
        Table srcAccounts = env.from("src_accounts");
        Table srcToFctTransactions =
                env.sqlQuery(
                        "SELECT txn_id, account_id, amount, currency, `timestamp`, status "
                                + "FROM src_transactions WHERE txn_id IS NOT NULL AND txn_id <> ''");

        StatementSet statementSet = env.createStatementSet();
        statementSet.add(rawToSrcAccounts.insertInto("src_accounts"));
        statementSet.add(srcAccounts.insertInto("dim_account"));
        statementSet.add(rawToSrcTransactions.insertInto("src_transactions"));
        statementSet.add(srcToFctTransactions.insertInto("fct_transactions"));

        statementSet.execute();
    }

    private CdcToSilverTableJob() {}
}
