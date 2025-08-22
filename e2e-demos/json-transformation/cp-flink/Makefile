CFNT_NS=confluent
FLCK_NS=flink
CMF_URL=http://localhost:8084


# ---------------------- Confluent Kafka ----------------------
use_cp_ns:
	@kubectl config set-context --current --namespace=$(CFNT_NS)

port_forward_cp_console:
	@osascript -e 'tell app "Terminal" to do script "kubectl -n $(CFNT_NS) port-forward svc/controlcenter-bootstrap-np 9021:9021"'
# ---------------------- Flink ----------------------
use_flink_ns:
	@kubectl config set-context --current --namespace=$(FLCK_NS)

list_compute_pools:
	@confluent flink compute-pool list --environment env1 --url $(CMF_URL)

port_forward_cmf:
	@osascript -e 'tell app "Terminal" to do script "kubectl port-forward svc/cmf-service 8084:80 -n $(FLCK_NS)"'

# --- demo setup ---

create_raw_contract_topic:
	@kubectl apply -f raw_contract_topic.yaml -n $(CFNT_NS)

create_raw_contract_cm:
	@kubectl apply -f raw_contract_cm.yaml -n $(CFNT_NS)

create_raw_contract_schema:
	@kubectl apply -f raw_contract_schema.yaml -n $(CFNT_NS)