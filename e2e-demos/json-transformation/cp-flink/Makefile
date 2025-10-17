CFNT_NS=confluent
FLCK_NS=flink
CMF_URL=http://localhost:8084

# Other services port forwarding
port-forward-minio-console:
	@osascript -e 'tell app "Terminal" to do script "kubectl port-forward pod/minio 9090 9090 -n $(MINIO_NS)"' -e 'tell application "Terminal" to set custom title of selected tab of the front window to "Minio Console"'


# ---------------------- Confluent Kafka ----------------------
use_cp_ns:
	@kubectl config set-context --current --namespace=$(CFNT_NS)

port_forward_cp_console:
	@osascript -e 'tell app "Terminal" to do script "kubectl -n $(CFNT_NS) port-forward svc/controlcenter-ng 9021:9021"'

port_forward_schema_registry:
	@osascript -e 'tell app "Terminal" to do script "kubectl -n $(CFNT_NS) port-forward svc/schemaregistry 8081:8081"'

port_forward_kafka_bootstrap:
	@osascript -e 'tell app "Terminal" to do script "kubectl -n $(CFNT_NS) port-forward svc/kafka 9092:9092"'


# ---------------------- Flink ----------------------
use_flink_ns:
	@kubectl config set-context --current --namespace=$(FLCK_NS)

list_compute_pools:
	@confluent flink compute-pool list --environment env1 --url $(CMF_URL)

port_forward_cmf:
	@osascript -e 'tell app "Terminal" to do script "kubectl port-forward svc/cmf-service 8084:80 -n $(FLCK_NS)"'

start_flink_shell:
	@osascript -e 'tell app "Terminal" to do script "confluent flink shell --environment env1 --compute-pool pool1 --url $(CMF_URL);"' -e 'tell application "Terminal" to set current settings of window 1 to settings set "Ocean"'


	