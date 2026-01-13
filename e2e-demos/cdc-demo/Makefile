# CDC Debezium Demo Makefile
# Demonstrates CDC from PostgreSQL to Kafka using Debezium, consumed by Flink SQL

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m

PGDB_NS=pgdb
CONFLUENT_NS=confluent

# ---------------------- Help ----------------------
help: ## Show this help message
	@echo "$(BLUE)CDC Debezium Demo Makefile$(NC)"
	@echo ""
	@echo "$(BLUE)Quick Start:$(NC)"
	@echo "  make demo_setup    - Complete setup (OrbStack + PostgreSQL + Confluent Platform + Connect)"
	@echo "  make demo_run      - Load data and deploy connector"
	@echo "  make demo_cleanup  - Clean up all resources"
	@echo ""
	@echo "$(BLUE)Available targets:$(NC)"
	@awk 'BEGIN {FS = ":.*##"; printf ""} /^[a-zA-Z_-]+:.*?##/ { printf "  $(GREEN)%-25s$(NC) %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

# ---------------------- Common functions ----------------------
ensure_ns = \
	@kubectl get ns $1 >/dev/null 2>&1; \
	if [ $$? -ne 0 ]; then \
			kubectl create ns $1; \
	else \
			echo "$1 exists";\
	fi

# ---------------------- OrbStack ----------------------
start_orbstack: ## Start OrbStack Kubernetes cluster
	@orb start k8s
	@echo "$(GREEN)OrbStack Kubernetes started$(NC)"
	@kubectl get ns

stop_orbstack: ## Stop OrbStack Kubernetes cluster
	@orb stop k8s
	@echo "$(GREEN)OrbStack Kubernetes stopped$(NC)"

# ---------------------- Demo Lifecycle ----------------------
demo_setup: start_orbstack deploy_postgresql_operator wait_postgresql_operator deploy_postgresql deploy_pgadmin ## Complete demo setup
	@echo "$(GREEN)Demo setup complete$(NC)"
	@echo "$(YELLOW)Next steps:$(NC)"
	@echo "  1. Ensure Confluent Platform is running: cd ../../deployment/k8s/cfk && make deploy"
	@echo "  2. Deploy Kafka Connect: make deploy_connect"
	@echo "  3. Load data and connector: make demo_run"

demo_run: load_data_psql deploy_connector ## Load data and deploy CDC connector
	@echo "$(GREEN)Demo running$(NC)"
	@echo "$(YELLOW)Verify CDC topics:$(NC)"
	@echo "  kubectl exec -it kafka-0 -n $(CONFLUENT_NS) -- kafka-topics --list --bootstrap-server localhost:9092 | grep cdc"

demo_cleanup: undeploy_connector undeploy_postgresql undeploy_pgadmin ## Clean up demo resources
	@echo "$(GREEN)Demo cleanup complete$(NC)"

# ---------------------- PostgreSQL ----------------------
deploy_postgresql_operator: ## Deploy CloudNativePG operator
	@echo "$(BLUE)Checking if CloudNativePG operator is already deployed...$(NC)"
	@if kubectl get deployment -n cnpg-system cnpg-controller-manager >/dev/null 2>&1; then \
		echo "$(YELLOW)CloudNativePG operator already deployed$(NC)"; \
	else \
		echo "$(BLUE)Deploying CloudNativePG operator...$(NC)"; \
		kubectl apply --server-side -f https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.27/releases/cnpg-1.27.1.yaml; \
	fi

wait_postgresql_operator: ## Wait for PostgreSQL operator to be ready
	@echo "$(BLUE)Waiting for CloudNativePG operator...$(NC)"
	@kubectl wait --for=condition=available deployment/cnpg-controller-manager -n cnpg-system --timeout=120s
	@echo "$(GREEN)CloudNativePG operator ready$(NC)"

verify_postgresql_operator: ## Verify PostgreSQL operator status
	@kubectl get deployment -n cnpg-system cnpg-controller-manager

deploy_postgresql: ## Deploy PostgreSQL cluster
	@echo "$(BLUE)Deploying PostgreSQL cluster...$(NC)"
	@kubectl apply -f infrastructure/pg-cluster.yaml
	@echo "$(YELLOW)Waiting for PostgreSQL cluster to be ready...$(NC)"
	@sleep 10
	@kubectl wait --for=condition=ready pod/pg-cluster-1 -n $(PGDB_NS) --timeout=180s
	@echo "$(GREEN)PostgreSQL cluster ready$(NC)"

verify_postgresql: ## Verify PostgreSQL cluster status
	@kubectl get cluster -n $(PGDB_NS)
	@kubectl get pods -n $(PGDB_NS)
	@kubectl get svc -n $(PGDB_NS)

undeploy_postgresql: ## Undeploy PostgreSQL cluster
	@kubectl delete -f infrastructure/pg-cluster.yaml --ignore-not-found

deploy_pgadmin: ## Deploy PGAdmin web UI
	@kubectl apply -f infrastructure/pg-admin.yaml
	@echo "$(GREEN)PGAdmin available at http://localhost:30001$(NC)"
	@echo "  Login: admin@example.com / password123"

undeploy_pgadmin: ## Undeploy PGAdmin
	@kubectl delete -f infrastructure/pg-admin.yaml --ignore-not-found

port_forward_pg: ## Port forward PostgreSQL for local access
	@echo "$(BLUE)Port-forwarding PostgreSQL...$(NC)"
	@osascript -e 'tell app "Terminal" to do script "kubectl port-forward pg-cluster-1 5432:5432 -n $(PGDB_NS)"'

get_pg_password: ## Get PostgreSQL app user password
	@echo "$(BLUE)PostgreSQL app user password:$(NC)"
	@kubectl get secret app-secret -n $(PGDB_NS) -o=jsonpath='{.data.password}' | base64 -d
	@echo ""

# ---------------------- Data Loading ----------------------
load_data: ## Load sample data into PostgreSQL (requires port-forward running)
	@echo "$(BLUE)Loading sample data...$(NC)"
	@echo "$(YELLOW)Ensure port-forward is running: make port_forward_pg$(NC)"
	@echo "$(YELLOW)Waiting for connection...$(NC)"
	@sleep 2
	@cd $(CURDIR) && uv run python src/create_loan_applications.py --small
	@cd $(CURDIR) && uv run python src/create_transactions.py --small
	@echo "$(GREEN)Data loaded successfully$(NC)"

load_data_with_pf: ## Load data with port-forward in background
	@echo "$(BLUE)Starting port-forward in background...$(NC)"
	@kubectl port-forward pg-cluster-1 5432:5432 -n $(PGDB_NS) &
	@sleep 5
	@echo "$(BLUE)Loading sample data...$(NC)"
	@cd $(CURDIR) && uv run python src/create_loan_applications.py --small
	@cd $(CURDIR) && uv run python src/create_transactions.py --small
	@echo "$(GREEN)Data loaded successfully$(NC)"
	@echo "$(YELLOW)Note: Port-forward is still running in background. Kill with: pkill -f 'port-forward pg-cluster'$(NC)"

test_pg_connection: ## Test PostgreSQL connection (requires port-forward)
	@echo "$(BLUE)Testing PostgreSQL connection...$(NC)"
	@cd $(CURDIR) && uv run python -c "import psycopg2; conn = psycopg2.connect(host='localhost', port=5432, database='app', user='app', password='apppwd'); print('Connection successful!'); conn.close()"

load_data_psql: create_tables_psql insert_data_psql ## Load data using psql exec into pod (no port-forward needed)
	@echo "$(GREEN)Tables created and data inserted$(NC)"

create_tables_psql: ## Create tables via kubectl exec
	@echo "$(BLUE)Creating tables via kubectl exec...$(NC)"
	@cat src/postgresql/create_tables.sql | kubectl exec -i pg-cluster-1 -n $(PGDB_NS) -- psql -U postgres -d app
	@echo "$(GREEN)Tables created$(NC)"

insert_data_psql: ## Insert sample data via kubectl exec
	@echo "$(BLUE)Inserting sample data...$(NC)"
	@cat src/postgresql/insert_sample_data.sql | kubectl exec -i pg-cluster-1 -n $(PGDB_NS) -- psql -U postgres -d app
	@echo "$(GREEN)Sample data inserted$(NC)"

verify_tables: ## Verify tables exist in PostgreSQL
	@kubectl exec -i pg-cluster-1 -n $(PGDB_NS) -- psql -U postgres -d app -c "\dt"
	@kubectl exec -i pg-cluster-1 -n $(PGDB_NS) -- psql -U postgres -d app -c "SELECT count(*) FROM loan_applications;"
	@kubectl exec -i pg-cluster-1 -n $(PGDB_NS) -- psql -U postgres -d app -c "SELECT count(*) FROM transactions;"

# ---------------------- Kafka Connect ----------------------
deploy_connect: ## Deploy Kafka Connect with Debezium plugin
	@echo "$(BLUE)Deploying Kafka Connect with Debezium...$(NC)"
	@kubectl apply -f infrastructure/debezium.yaml
	@kubectl apply -f infrastructure/kconnect.yaml
	@echo "$(YELLOW)Waiting for Connect to be ready (this may take a few minutes)...$(NC)"
	@sleep 30
	@kubectl wait --for=condition=ready pod -l app=connect -n $(CONFLUENT_NS) --timeout=300s || true
	@echo "$(GREEN)Kafka Connect deployed$(NC)"

verify_connect: ## Verify Kafka Connect status
	@kubectl get pods -n $(CONFLUENT_NS) -l app=connect
	@kubectl get svc -n $(CONFLUENT_NS) | grep connect

undeploy_connect: ## Undeploy Kafka Connect
	@kubectl delete -f infrastructure/kconnect.yaml --ignore-not-found
	@kubectl delete -f infrastructure/debezium.yaml --ignore-not-found

port_forward_connect: ## Port forward Connect REST API
	@echo "$(BLUE)Port-forwarding Connect REST API...$(NC)"
	@osascript -e 'tell app "Terminal" to do script "kubectl port-forward connect-0 8083:8083 -n $(CONFLUENT_NS)"'

# ---------------------- Debezium Connector ----------------------
prepare_cdc: ## Grant REPLICATION to app user and create CDC topics
	@echo "$(BLUE)Granting REPLICATION privilege to app user...$(NC)"
	@kubectl exec -i pg-cluster-1 -n $(PGDB_NS) -- psql -U postgres -c "ALTER USER app REPLICATION;"
	@echo "$(BLUE)Creating CDC topics...$(NC)"
	@kubectl exec -i kafka-0 -n $(CONFLUENT_NS) -- kafka-topics --create --topic cdc.public.transactions --bootstrap-server kafka:9071 --partitions 1 --replication-factor 1 --if-not-exists 2>/dev/null || true
	@kubectl exec -i kafka-0 -n $(CONFLUENT_NS) -- kafka-topics --create --topic cdc.public.loan_applications --bootstrap-server kafka:9071 --partitions 1 --replication-factor 1 --if-not-exists 2>/dev/null || true
	@kubectl exec -i kafka-0 -n $(CONFLUENT_NS) -- kafka-topics --create --topic schema-changes.cdc --bootstrap-server kafka:9071 --partitions 1 --replication-factor 1 --if-not-exists 2>/dev/null || true
	@echo "$(GREEN)CDC preparation complete$(NC)"

deploy_connector: prepare_cdc ## Deploy Debezium PostgreSQL connector
	@echo "$(BLUE)Deploying Debezium connector...$(NC)"
	@make port_forward_connect
	@sleep 3
	@curl -X POST -H "Content-Type: application/json" \
		--data @infrastructure/cdc_debezium.json \
		http://localhost:8083/connectors
	@echo ""
	@echo "$(GREEN)Connector deployed$(NC)"

verify_connector: ## Verify connector status
	@curl -s localhost:8083/connectors/tx-loan-connector/status | jq .
	@curl -s localhost:8083/connectors/tx-loan-connector/status | jq .

list_connectors: ## List all connectors
	@curl -s localhost:8083/connectors/ | jq .

undeploy_connector: ## Delete Debezium connector
	@curl -X DELETE localhost:8083/connectors/tx-loan-connector || true
	@echo "$(GREEN)Connector deleted$(NC)"

# ---------------------- Kafka Topics ----------------------
list_cdc_topics: ## List CDC topics in Kafka
	@kubectl exec -i kafka-0 -n $(CONFLUENT_NS) -- kafka-topics --list --bootstrap-server kafka:9071 | grep cdc

consume_loan_applications: ## Consume messages from loan_applications CDC topic
	@kubectl exec -i kafka-0 -n $(CONFLUENT_NS) -- kafka-console-consumer \
		--bootstrap-server kafka:9071 \
		--topic cdc.public.loan_applications \
		--from-beginning \
		--max-messages 5 \
		--timeout-ms 10000

consume_transactions: ## Consume messages from transactions CDC topic
	@kubectl exec -i kafka-0 -n $(CONFLUENT_NS) -- kafka-console-consumer \
		--bootstrap-server kafka:9071 \
		--topic cdc.public.transactions \
		--from-beginning \
		--max-messages 5 \
		--timeout-ms 10000

# ---------------------- Verification ----------------------
verify_installation: ## Verify all components are running
	@echo "$(BLUE)Checking cert-manager...$(NC)"
	@kubectl get pods -n cert-manager
	@echo ""
	@echo "$(BLUE)Checking Confluent Platform...$(NC)"
	@kubectl get pods -n $(CONFLUENT_NS)
	@echo ""
	@echo "$(BLUE)Checking PostgreSQL...$(NC)"
	@kubectl get pods -n $(PGDB_NS)

# ---------------------- Flink SQL ----------------------
show_flink_ddl: ## Display Flink SQL DDL for CDC tables
	@echo "$(BLUE)Flink SQL DDL for loan_applications:$(NC)"
	@cat src/flink-sql/ddl.loan_applications.sql
	@echo ""
	@echo "$(BLUE)Flink SQL DDL for transactions:$(NC)"
	@cat src/flink-sql/ddl.transactions.sql

port_forward_cmf: ## Port forward Confluent Manager for Flink (CMF) on port 8084
	@echo "$(BLUE)Port-forwarding CMF on port 8084...$(NC)"
	@osascript -e 'tell app "Terminal" to do script "kubectl port-forward svc/cmf-service 8084:80 -n $(CONFLUENT_NS)"'
	@echo "$(GREEN)CMF available at http://localhost:8084$(NC)"

flink_shell: ## Open Flink SQL shell via CMF (requires valid license)
	@echo "$(BLUE)Opening Flink SQL shell...$(NC)"
	@confluent flink shell --environment dev-env --url http://localhost:8084

# ---------------------- Apache Flink OSS ----------------------
FLINK_NS=flink-cdc

deploy_flink: ## Deploy Apache Flink session cluster for CDC demo
	@echo "$(BLUE)Deploying Apache Flink session cluster...$(NC)"
	@kubectl apply -f infrastructure/flink/namespace.yaml
	@kubectl apply -f infrastructure/flink/flink-config.yaml
	@kubectl apply -f infrastructure/flink/jobmanager.yaml
	@kubectl apply -f infrastructure/flink/taskmanager.yaml
	@echo "$(YELLOW)Waiting for Flink JobManager to be ready...$(NC)"
	@sleep 10
	@kubectl wait --for=condition=available deployment/flink-jobmanager -n $(FLINK_NS) --timeout=180s || true
	@echo "$(GREEN)Flink cluster deployed$(NC)"
	@echo "$(YELLOW)Access Flink UI: make port_forward_flink_ui$(NC)"

undeploy_flink: ## Undeploy Apache Flink session cluster
	@kubectl delete -f infrastructure/flink/taskmanager.yaml --ignore-not-found
	@kubectl delete -f infrastructure/flink/jobmanager.yaml --ignore-not-found
	@kubectl delete -f infrastructure/flink/flink-config.yaml --ignore-not-found
	@echo "$(GREEN)Flink cluster removed$(NC)"

verify_flink: ## Verify Flink cluster status
	@echo "$(BLUE)Flink pods:$(NC)"
	@kubectl get pods -n $(FLINK_NS)
	@echo ""
	@echo "$(BLUE)Flink services:$(NC)"
	@kubectl get svc -n $(FLINK_NS)

port_forward_flink_ui: ## Port forward Flink Web UI on port 8081
	@echo "$(BLUE)Port-forwarding Flink UI on port 8081...$(NC)"
	@osascript -e 'tell app "Terminal" to do script "kubectl port-forward svc/flink-jobmanager 8081:8081 -n $(FLINK_NS)"'
	@echo "$(GREEN)Flink UI available at http://localhost:8081$(NC)"

flink_sql_client: ## Open Flink SQL client (Apache Flink OSS)
	@echo "$(BLUE)Opening Flink SQL client...$(NC)"
	@echo "$(YELLOW)Tip: Use the DDL files in src/flink-sql/ to create tables$(NC)"
	@kubectl exec -it $$(kubectl get pods -n $(FLINK_NS) -l component=jobmanager -o jsonpath='{.items[0].metadata.name}') -n $(FLINK_NS) -- /opt/flink/bin/sql-client.sh
