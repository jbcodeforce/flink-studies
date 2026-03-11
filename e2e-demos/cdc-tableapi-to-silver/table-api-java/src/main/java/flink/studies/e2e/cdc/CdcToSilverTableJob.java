package flink.studies.e2e.cdc;

import io.confluent.flink.plugin.ConfluentSettings;
import io.confluent.flink.plugin.ConfluentTableDescriptor;
import org.apache.flink.table.api.DataTypes;
import org.apache.flink.table.api.EnvironmentSettings;
import org.apache.flink.table.api.Schema;
import org.apache.flink.table.api.StatementSet;
import org.apache.flink.table.api.Table;
import org.apache.flink.table.api.TableEnvironment;

import java.util.Arrays;

/**
 * Single Flink Table API job: raw Debezium Kafka topics → silver tables → dimension (dim_account)
 * and fact (fct_transactions). Uses a StatementSet to run all four pipelines in one job.
 *
 * <p>Deployment is selected by the first program argument (default: CC):
 * <ul>
 *   <li><b>CC</b> – Confluent Cloud: uses {@link io.confluent.flink.plugin.ConfluentSettings} from
 *       environment/global variables. Set FLINK_ENV_NAME and FLINK_DATABASE_NAME for catalog/database.
 *   <li><b>LOCAL</b> (or <b>FLINK</b>) – Apache Flink local: uses standard {@link
 *       EnvironmentSettings} in streaming mode (built-in catalog/database unless FLINK_ENV_NAME
 *       and FLINK_DATABASE_NAME are set).
 * </ul>
 * Raw tables (raw_accounts, raw_transactions) must exist and be populated separately; this job
 * creates silver/dim/fact tables and runs the pipelines.
 */
public final class CdcToSilverTableJob {

    private static final String DEPLOYMENT_CC = "CC";
    private static final String DEPLOYMENT_LOCAL = "LOCAL";
    private static final String DEPLOYMENT_FLINK = "FLINK";


    private static final String DDL_SRC_ACCOUNTS =
            "CREATE TABLE IF NOT EXISTS tp_src_accounts ("
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
            "CREATE TABLE IF NOT EXISTS tp_src_transactions ("
                    + "txn_id STRING,"
                    + "account_id STRING,"
                    + "amount DECIMAL(10, 2),"
                    + "currency STRING,"
                    + "tx_ms TIMESTAMP_LTZ(3),"
                    + "status STRING,"
                    + "WATERMARK FOR `tx_ms` AS `tx_ms` - INTERVAL '5' SECOND,"
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
            "CREATE TABLE IF NOT EXISTS tp_dim_accounts ("
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
                    + "TO_TIMESTAMP_LTZ(`source`.ts_ms, 3) AS `tx_ms`,"
                    + "COALESCE(IF(op = 'd', `before`.status, `after`.status), '') AS status "
                    + "FROM raw_transactions WHERE `source`.ts_ms IS NOT NULL";

    public static void main(String[] args) {
        String deployment = args.length > 0 ? args[0].trim().toUpperCase() : DEPLOYMENT_CC;
        EnvironmentSettings settings = createEnvironmentSettings(deployment);
        TableEnvironment env = TableEnvironment.create(settings);
        env.getConfig().set("client.statement-name", "cdc-to-silver-table-job");

        String catalog = System.getenv("FLINK_ENV_NAME");
        String database = System.getenv("FLINK_DATABASE_NAME");
        if (catalog != null && !catalog.isEmpty()) {
            env.useCatalog(catalog);
        }
        if (database != null && !database.isEmpty()) {
            env.useDatabase(database);
        }

        if (! (tableExists(env, "tp_src_accounts"))) {
                env.executeSql(DDL_SRC_ACCOUNTS);
        }
        if (! (tableExists(env, "tp_src_transactions"))) {
            env.executeSql(DDL_SRC_TRANSACTIONS);
        }
        if (! (tableExists(env, "tp_dim_accounts"))) {
            env.executeSql(DDL_DIM_ACCOUNT);
        }
        if (! (tableExists(env, "tp_fct_transactions"))) {
            createFctTransactionsTable(env);
        }

        Table rawToSrcAccountsQuery = env.sqlQuery(SELECT_RAW_TO_SRC_ACCOUNTS);
        Table rawToSrcTransactionsQuery = env.sqlQuery(SELECT_RAW_TO_SRC_TRANSACTIONS);
        Table dimAccounts = env.sqlQuery("select * from tp_src_accounts where is_deleted is null or is_deleted = false");

        Table dimAccountToFctTransactions =
                env.sqlQuery(
                        "select t.txn_id, t.account_id, a.account_name, a.region, a.is_deleted, t.amount,t.currency, t.tx_ms, t.status "
                        + "from `tp_src_transactions` t left join `tp_dim_accounts` a on t.`account_id` = a.`account_id`");

        StatementSet statementSet = env.createStatementSet();
        statementSet.add(rawToSrcAccountsQuery.insertInto("tp_src_accounts"));
        statementSet.add(rawToSrcTransactionsQuery.insertInto("tp_src_transactions"));
        statementSet.add(dimAccounts.insertInto("tp_dim_accounts"));     
        statementSet.add(dimAccountToFctTransactions.insertInto("tp_fct_transactions"));
        statementSet.execute();
    }

    /**
     * Creates the fact transactions table using the Table API (ConfluentTableDescriptor). Equivalent
     * to the former DDL for tp_fct_transactions: Kafka-backed, upsert, avro-registry, watermark on
     * timestamp, primary key txn_id. No-op if the table already exists.
     */
    private static void createFctTransactionsTable(TableEnvironment env) {
        env.createTable(
                "tp_fct_transactions",
                ConfluentTableDescriptor.forManaged()
                        .schema(
                                Schema.newBuilder()
                                        .column("txn_id", DataTypes.STRING().notNull())
                                        .column("account_id", DataTypes.STRING())
                                        .column("account_name", DataTypes.STRING())
                                        .column("region", DataTypes.STRING())
                                        .column("is_deleted", DataTypes.BOOLEAN())
                                        .column("amount", DataTypes.DECIMAL(10, 2))
                                        .column("currency", DataTypes.STRING())
                                        .column("tx_ms", DataTypes.TIMESTAMP_LTZ(3))
                                        .column("status", DataTypes.STRING())
                                        .primaryKey("txn_id")
                                        .watermark("tx_ms", "tx_ms - INTERVAL '5' SECOND")
                                        .build())
                        .distributedBy(1, "txn_id")
                        .option("changelog.mode", "upsert")
                        .option("key.avro-registry.schema-context", ".flink-dev")
                        .option("value.avro-registry.schema-context", ".flink-dev")
                        .option("key.format", "avro-registry")
                        .option("value.format", "avro-registry")
                        .option("kafka.retention.time", "0")
                        .option("kafka.producer.compression.type", "snappy")
                        .option("scan.bounded.mode", "unbounded")
                        .option("scan.startup.mode", "earliest-offset")
                        .option("value.fields-include", "all")
                        .build());
    }

    /** Returns true if a table with the given name exists in the current catalog and database. */
    private static boolean tableExists(TableEnvironment env, String tableName) {
        return Arrays.asList(env.listTables()).contains(tableName);
    }

    /**
     * Creates environment settings for the given deployment: Confluent Cloud (CC) or local Apache
     * Flink (LOCAL / FLINK). Unknown values default to local Flink.
     */
    private static EnvironmentSettings createEnvironmentSettings(String deployment) {
        if (DEPLOYMENT_CC.equals(deployment)) {
            return ConfluentSettings.fromGlobalVariables();
        }
        if (DEPLOYMENT_LOCAL.equals(deployment) || DEPLOYMENT_FLINK.equals(deployment)) {
            return EnvironmentSettings.newInstance().inStreamingMode().build();
        }
        return EnvironmentSettings.newInstance().inStreamingMode().build();
    }

    private CdcToSilverTableJob() {}
}
