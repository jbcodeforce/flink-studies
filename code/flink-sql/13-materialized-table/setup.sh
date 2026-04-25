export FLINK_HOME=$(pwd)/../../deployment/product-tar/flink-2.2.0
mkdir -p savepoints 
mkdir -p checkpoints
mkdir -p  flink-catalog-store
mkdir -p  flink-catalog
mkdir -p  flink-catalog/mydb
curl -X GET https://repo.maven.apache.org/maven2/org/apache/flink/flink-table-filesystem-test-utils/2.2.0/flink-table-filesystem-test-utils-2.2.0.jar -o flink-table-filesystem-test-utils-2.2.0.jar   
mv flink-table-filesystem-test-utils-2.2.0.jar $FLINK_HOME/lib
export FLINK_CONF_DIR=$(pwd)
export FLINK_CATALOG_STORE_DIR=$(pwd)/flink-catalog-store