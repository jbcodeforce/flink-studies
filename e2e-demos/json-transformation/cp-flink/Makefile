CFNT_NS=confluent
FLCK_NS=confluent
MINIO_NS=minio-dev
CMF_URL=http://localhost:8084
DEMO_NS=rental
FLINK_ENV=dev-env
FLINK_COMPUTE_POOL=rental-pool

# Other services port forwarding
port_forward_minio_console:
	@osascript -e 'tell app "Terminal" to do script "kubectl port-forward pod/minio 9090 9090 -n $(MINIO_NS)"' -e 'tell application "Terminal" to set custom title of selected tab of the front window to "Minio Console"'


# ---------------------- Confluent Kafka ----------------------
use_cp_ns:
	@kubectl config set-context --current --namespace=$(CFNT_NS)

port_forward_cp_console:
	@osascript -e 'tell app "Terminal" to do script "kubectl -n $(CFNT_NS) port-forward svc/controlcenter-ng 9021:9021"' -e 'tell application "Terminal" to set custom title of selected tab of the front window to "CP Console"'

port_forward_schema_registry:
	@osascript -e 'tell app "Terminal" to do script "kubectl -n $(CFNT_NS) port-forward svc/schemaregistry 8081:8081"' -e 'tell application "Terminal" to set custom title of selected tab of the front window to "Schema Registry"'

port_forward_kafka_bootstrap:
	@osascript -e 'tell app "Terminal" to do script "kubectl -n $(CFNT_NS) port-forward svc/kafka 9092:9092"' -e 'tell application "Terminal" to set custom title of selected tab of the front window to "Kafka Bootstrap"'


# ---------------------- Flink ----------------------
use_flink_ns:
	@kubectl config set-context --current --namespace=$(FLCK_NS)

list_compute_pools:
	@confluent flink compute-pool list --environment env1 --url $(CMF_URL)

port_forward_cmf:
	@osascript -e 'tell app "Terminal" to do script "kubectl port-forward svc/cmf-service 8084:80 -n $(FLCK_NS)"' -e 'tell application "Terminal" to set custom title of selected tab of the front window to "CMF REST API"'

start_flink_shell:
	@osascript -e 'tell app "Terminal" to do script "confluent flink shell --environment $(FLINK_ENV) --compute-pool $(FLINK_COMPUTE_POOL) --url $(CMF_URL);"' -e 'tell application "Terminal" to set custom title of selected tab of the front window to "Flink Shell"'

define_catalog:
	@confluent flink catalog create k8s/kafka-catalog-cmf.json --url $(CMF_URL)

stop_port_forwards:
	@echo "Stopping all port forwards..."
	@pkill -f "kubectl.*port-forward" || true
	@echo "All port forwards stopped"
	@echo "Closing specific Terminal windows..."
	@osascript -e 'tell application "Terminal"' \
		-e 'set windowTitles to {"Minio Console", "CP Console", "CMF REST API", "Schema Registry", "Kafka Bootstrap"}' \
		-e 'if number of windows > 0 then' \
		-e '  repeat with w in windows' \
		-e '    try' \
		-e '      set winTitle to custom title of w' \
		-e '      if winTitle is in windowTitles then' \
		-e '        close w' \
		-e '      end if' \
		-e '    end try' \
		-e '  end repeat' \
		-e 'end if' \
		-e 'end tell'
	@echo "Port forward Terminal windows closed"

# ----- Flink Application -----
use_demo_ns:
	@kubectl config set-context --current --namespace=$(DEMO_NS)

build:
	@echo "$(YELLOW)Building Flink application...$(NC)"
	cd table_api && mvn package
	cd table_api && docker build -t rental-dsp:latest .

deploy:
	@echo "$(YELLOW)Deploying Flink application...$(NC)"
	kubectl apply -f k8s/flink-application.yaml -n $(DEMO_NS)

status:
	@echo "$(YELLOW)Checking Flink application status...$(NC)"
	kubectl describe flinkapplication rental-dsp -n $(DEMO_NS)

undeploy:
	@echo "$(YELLOW)Deploying Flink application...$(NC)"
	kubectl delete -f k8s/flink-application.yaml -n $(DEMO_NS)