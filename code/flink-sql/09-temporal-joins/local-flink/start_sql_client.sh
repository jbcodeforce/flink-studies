FLINK_HOME=/Users/jerome/Documents/Code/flink-studies/deployment/product-tar/flink-2.1.1
PATH=$PATH:$FLINK_HOME/bin
$FLINK_HOME/bin/sql-client.sh embedded -i /Users/jerome/Documents/Code/flink-studies/code/flink-sql/09-temporal-joins/local-flink/temporal_joins.sql