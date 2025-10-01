CFNT_NS=confluent
FLCK_NS=flink
DEMO_NS=el-demo
DUCKDB_NS=duckdb
CERT_MGR_VERSION=v1.18.1
FLINK_OPERATOR_VERSION=1.11.0
CMF_URL=http://localhost:8084
ENV_NAME=env1
DUCKDB_APP_NAME=duckdb-external-lookup


# ---------------------- Common functions ----------------------
ensure_ns = \
	@kubectl get ns $1 >/dev/null 2>&1; \
	if [ $$? -ne 0 ]; then \
			kubectl create ns $1; \
	else \
			echo "$1 exists";\
	fi


# ---------------------- Colima ----------------------
start_colima:
	@colima start --cpu 8 --memory 24 --kubernetes

stop_colima:
	@colima stop

set_docker_context:
	@docker context use colima

# ------- Common elements to install -------------
prepare: create_ns 

create_ns:
	$(call ensure_ns, $(DEMO_NS))

use_demo_ns:
	@kubectl config set-context --current --namespace=$(DEMO_NS)

use_flink_ns:
	@kubectl config set-context --current --namespace=$(FLCK_NS)

use_cp_ns:
	@kubectl config set-context --current --namespace=$(CFNT_NS)

# ---------------------- Confluent Platform ----------------------
port_forward_cp_console:
	@osascript -e 'tell app "Terminal" to do script "kubectl -n $(CFNT_NS) port-forward svc/controlcenter-ng 9021:9021"' -e 'tell application "Terminal" to set current settings of front window to settings set "Pro"'


port_forward_kafka_bootstrap:
	@osascript -e 'tell app "Terminal" to do script "kubectl -n $(CFNT_NS) port-forward svc/kafka 9092:9092"'

# ---------------------- Confluent Manager for Flink ----------------------

port_forward_cmf:
	@osascript -e 'tell app "Terminal" to do script "kubectl port-forward svc/cmf-service 8084:80 -n $(FLCK_NS)"'

list_flink_env:
	@confluent flink environment list --url $(CMF_URL)

create_compute_pool:
	@confluent flink compute-pool create ../cmf/compute_pool.json --environment $(ENV_NAME) --url $(CMF_URL)

list_compute_pools:
	@confluent flink compute-pool list --environment $(ENV_NAME) --url $(CMF_URL)



# ----------- Applications ----------------------

port_forward_duckdb_api:
	@echo "Getting DuckDB pod name and starting port-forward..."
	@POD_NAME=$$(kubectl get pods -n $(DUCKDB_NS) -l app=$(DUCKDB_APP_NAME) -o jsonpath='{.items[0].metadata.name}' 2>/dev/null); \
	if [ -n "$$POD_NAME" ]; then \
		echo "Port-forwarding to pod: $$POD_NAME"; \
		osascript -e "tell app \"Terminal\" to do script \"kubectl -n $(DUCKDB_NS) port-forward pod/$$POD_NAME 8080:8080\"" -e 'tell application "Terminal" to set current settings of front window to settings set "Ocean"'; \
	else \
		echo "❌ No DuckDB pods found in namespace $(DUCKDB_NS)"; \
		echo "Available pods:"; \
		kubectl get pods -n $(DUCKDB_NS); \
	fi

port_forward_event_generator_metrics:
	@osascript -e 'tell app "Terminal" to do script "kubectl -n $(DEMO_NS) port-forward svc/event-generator-metrics 8090:8090"' -e 'tell application "Terminal" to set current settings of front window to settings set "Grass"'

expose_services:
	make port_forward_cp_console
	make port_forward_duckdb_api
	make port_forward_cmf
