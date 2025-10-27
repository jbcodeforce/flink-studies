# Environment variables
CFNT_NS=confluent
FLCK_NS=confluent
DEMO_NS=rental
MINIO_NS=minio-dev
CMF_URL=http://localhost:8084
SR_URL=http://localhost:8081
ENV_NAME=dev-rental
APP_NAME=json-xform
POOL_NAME=demos-pool

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
WHITE := \033[0;37m
NC := \033[0m

# GOALS: 
# Define infrastructure for the demo common to the different components.
# build all the components, exposes all the services needed for the demo, open the web page and the control center console.
# Create Flink Environment, Compute Pool, Catalog, Topics, Schemas, ConfigMaps, and Data.
# Delegates to the different components to build and deploy their own applications.
# ---------------------- Common functions ----------------------
ensure_ns = \
	@kubectl get ns $1 >/dev/null 2>&1; \
	if [ $$? -ne 0 ]; then \
			kubectl create ns $1; \
	else \
			echo "namespace: $1 exists";\
	fi

# --------- Build targets ---------
.PHONY: help build_all deploy_all status_all

help: ## Show this help message
	@echo "$(BLUE)Json Transformation Demo - Build & Deploy$(NC)"
	@echo ""
	@echo "$(BLUE)Available targets:$(NC)"
	@awk 'BEGIN {FS = ":.*##"; printf ""} /^[a-zA-Z_-]+:.*?##/ { printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

use_demo_ns: ## Use the rental namespace
	@kubectl config set-context --current --namespace=$(DEMO_NS)

use_confluent_ns: ## Use the confluent namespace	
	@kubectl config set-context --current --namespace=$(CFNT_NS)

# entry points
build_all: ## Build the demonstation components
	@echo "$(BLUE)Building demo...$(NC)"
	kubectl apply -f k8s/rental.yaml
	kubectl apply -f k8s/kafka_client_cm.yaml -n $(CFNT_NS)
	kubectl apply -f k8s/kafka_client_cm.yaml -n $(DEMO_NS)
	kubectl apply -f k8s/rbac.yaml -n $(DEMO_NS)
	make create_all_topics
	make create_all_schemas
	make create_environment
	make create_compute_pool
	make create_catalog
	cd src/demo-app && make build 
	cd src/cp-flink && make build

deploy_all: ## Deploy the demonstation components
	@echo "$(BLUE)Deploying demo...$(NC)"
	cd src/demo-app && make deploy
	@echo "Producer App Web Page should be visible at http://localhost:30080"
	cd src/cp-flink && make deploy
	make message


status_all: ## Validate the demo
	@echo "--------------------------------"
	@echo "$(BLUE)Validating demo...$(NC)"
	@echo "--------------------------------"
	cd src/demo-app && make status
	make status_all_topics
	make status_all_schemas
	make status_compute_pool
	cd src/cp-flink && make status
	@echo "$(WHITE) $(BOLD)Checking Flink environment...$(NC)"
	confluent flink environment list --url $(CMF_URL)
	@echo "----------------------------------------"
	@echo "$(WHITE)$(BOLD)Checking Flink catalog...$(NC)"
	@echo "----------------------------------------"
	confluent flink catalog list --url $(CMF_URL)
	@echo "----------------------------------------"
	@echo "$(WHITE)$(BOLD)Checking Flink compute pool...$(NC)"
	confluent flink compute-pool list --environment $(ENV_NAME) --url $(CMF_URL)
	@echo "----------------------------------------"
	@echo "✅ Demo status check complete!"

undeploy_all: ## Tear down the demo
	@echo "$(BLUE)Tearing down demo...$(NC)"
	cd src/demo-app && make undeploy
	cd src/cp-flink && make undeploy
	make delete_all_schemas
	make delete_all_cms
	make delete_all_topics
	make delete_compute_pool
	make delete_catalog
	make delete_secret
	make delete_secret_mapping
	make delete_environment
	make delete_ns

expose_services: ## Expose all the services needed for the demo
	@echo "$(BLUE)Exposing services...$(NC)"
	make port_forward_cp_console
	cd src/cp-flink && make port_forward_cmf
	make port_forward_schema_registry
	make port_forward_minio_console
	# cd src/cp-flink && make port_forward_kafka_bootstrap

port_forward_cp_console: ## Port forward the Confluent Platform console.
	@osascript -e 'tell app "Terminal" to do script "kubectl -n $(CFNT_NS) port-forward svc/controlcenter-ng 9021:9021"'  -e 'tell application "Terminal" to set custom title of selected tab of the front window to "C3"'

port_forward_schema_registry: ## Port forward the Schema Registry
	@osascript -e 'tell app "Terminal" to do script "kubectl -n $(CFNT_NS) port-forward svc/schemaregistry 8081:8081"' -e 'tell application "Terminal" to set custom title of selected tab of the front window to "Schemma Registry"'

port_forward_minio_console:
	@osascript -e 'tell app "Terminal" to do script "kubectl port-forward pod/minio 9090 9090 -n $(MINIO_NS)"' -e 'tell application "Terminal" to set custom title of selected tab of the front window to "Minio"'

open_cp_console: ## Open Confluent Control Center console
	@echo "$(BLUE)Opening Confluent Control Center on http://localhost:9021 ...$(NC)"
	@open -a "Google Chrome" http://localhost:9021

open_demo_web_page: ## Open the demo web page
	@echo "$(BLUE)Opening demo web page on http://localhost:30080 ...$(NC)"
	@open -a "Google Chrome" http://localhost:30080

open_minio_console: ## Open Minio console
	@echo "$(BLUE)Opening demo web page on http://localhost:9090 ...$(NC)"
	@open -a "Google Chrome" http://localhost:9090/browser

# ------ PRIVATE TARGETS ------

stop_port_forwards:
	@echo "Stopping all port forwards..."
	@pkill -f "kubectl.*port-forward" || true
	@echo "All port forwards stopped"
	@echo "Closing specific Terminal windows..."
	@osascript -e 'tell application "Terminal"' \
		-e 'set windowTitles to {"Minio", "C3", "CMF REST API", "Schema Registry", "Kafka Bootstrap"}' \
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

# Complete setup for demo
message:
	@echo "✅ Demo setup complete!"
	@echo "📋 Next steps:"
	@echo "  🌐 Web Interface: http://localhost:30080"
	@echo "  📊 Job History Dashboard: http://localhost:30080/job-history"
	@echo "  🔗 Port-forward alternative: 'make port_forward_producer_api' then http://localhost:8080"
	@echo "  📚 API Docs: http://localhost:30080/docs"
	@echo "  🔍 Health Check: 'make test_api_health_nodeport'"

# ---------------- Flink Environment ----------------
create_environment:
	@confluent flink environment create k8s/flink_dev_rental.yaml --url $(CMF_URL)

delete_environment:
	@confluent flink environment delete $(ENV_NAME) --url $(CMF_URL) --force
	@echo "$(GREEN)Environment deleted successfully$(NC)"

create_compute_pool:
	@echo "$(YELLOW)Creating compute pool...$(NC)"
	confluent flink compute-pool create k8s/compute-pool-cmf.json --environment $(ENV_NAME) --url $(CMF_URL)

delete_compute_pool:
	@if confluent flink compute-pool list --url $(CMF_URL) --environment $(FLINK_ENV) | grep -q "$(POOL_NAME)"; then \
		echo "$(GREEN)Compute pool '$(POOL_NAME)' found. Deleting...$(NC)"; \
		confluent flink compute-pool delete $(POOL_NAME) --environment $(FLINK_ENV) --url $(CMF_URL) --force; \
		echo "$(GREEN)Compute pool deleted successfully.$(NC)"; \
	else \
		echo "$(YELLOW)Compute pool '$(POOL_NAME)' not found. Nothing to undeploy.$(NC)"; \
	fi



status_compute_pool:
	@echo "$(YELLOW)Checking compute pool...$(NC)"
	confluent flink compute-pool list --environment $(ENV_NAME) --url $(CMF_URL)

create_secret:
	@echo "$(YELLOW)Creating secrets...$(NC)"
	@curl -X POST -H "Content-Type: application/json" -v -d @k8s/kafka_secrets.json $(CMF_URL)/cmf/api/v1/secrets

delete_secret:
	@echo "$(YELLOW)Deleting secrets...$(NC)"
	@curl -v -X DELETE $(CMF_URL)/cmf/api/v1/secrets/kafka-1-secret --ignore-not-found=true

map_secret:
	@echo "$(YELLOW)Mapping secrets...$(NC)"
	@curl -X POST -H "Content-Type: application/json" -v -d @k8s/kafka_secret_mapping.json $(CMF_URL)/cmf/api/v1/environments/$(ENV_NAME)/secret-mappings

delete_secret_mapping:
	@echo "$(YELLOW)Deleting secret mapping...$(NC)"
	@curl -v -X DELETE $(CMF_URL)/cmf/api/v1/environments/$(ENV_NAME)/secret-mappings/kafka-1-secret-id

create_catalog:
	@if ! `confluent flink catalog list --url $(CMF_URL) | grep -qw rental`; then \
		confluent flink catalog create k8s/kafka_catalog_cmf.json --url $(CMF_URL) -o human\
	else \
		echo "$(YELLOW)Catalog 'rental' already exists; skipping creation.$(NC)"; \
	fi
	
delete_catalog:
	@confluent flink catalog delete rental --url $(CMF_URL) --force --ignore-not-found=true
	@echo "$(GREEN)Catalog deleted successfully$(NC)"

list_kafka_catalogs:
	@confluent flink catalog list --url $(CMF_URL)

# ---- topics -----
create_all_topics:
	@echo "Creating all topics...in namespace $(CFNT_NS)"
	@kubectl apply -f k8s/topics/raw_orders_topic.yaml -n $(CFNT_NS)
	@kubectl apply -f k8s/topics/raw_jobs_topic.yaml -n $(CFNT_NS)
	@kubectl apply -f k8s/topics/order_details_topic.yaml -n $(CFNT_NS)

status_all_topics:
	@echo "--------------------------------"
	@echo "$(WHITE)Checking all topics...$(NC)"
	@echo "--------------------------------"
	@kubectl get KafkaTopics -n $(CFNT_NS)

delete_all_topics:
	@kubectl delete -f k8s/topics/raw_orders_topic.yaml -n $(CFNT_NS) --ignore-not-found=true
	@kubectl delete -f k8s/topics/raw_jobs_topic.yaml -n $(CFNT_NS) --ignore-not-found=true
	@kubectl delete -f k8s/topics/order_details_topic.yaml -n $(CFNT_NS) --ignore-not-found=true

# ---- Schemas with ConfigMaps
status_all_schemas:
	@echo "--------------------------------"
	@echo "$(WHITE)Checking all ConfigMaps and schemas...in namespace $(CFNT_NS)$(NC)"
	@echo "--------------------------------"
	@echo "$(WHITE)ConfigMaps:$(NC)"
	@kubectl get ConfigMap -n $(CFNT_NS)
	@echo "--------------------------------"
	@echo "$(WHITE)Schemas:$(NC)"
	@kubectl get schema -n $(CFNT_NS)
	@echo "--------------------------------"


# ----- orders -----
create_raw_orders_cm:
	@echo "$(YELLOW)Creating raw-orders ConfigMap from schema file...$(NC)"
	@kubectl create configmap raw-orders-value \
		--from-file=schema=src/schemas/raw_orders_schema.json \
		-n $(CFNT_NS) \
		--dry-run=client -o yaml | kubectl apply -f -


delete_raw_orders_cm:
	@kubectl delete -f k8s/schemas/raw_orders_cm.yaml -n $(CFNT_NS) --ignore-not-found=true

create_order_details_cm:
	@echo "$(YELLOW)Creating order-details ConfigMap from schema file...$(NC)"
	@kubectl create configmap order-details-value \
		--from-file=schema=src/schemas/order_details_schema.json \
		-n $(CFNT_NS) \
		--dry-run=client -o yaml | kubectl apply -f -

delete_order_details_cm:
	@kubectl delete -f k8s/schemas/order_details_cm.yaml -n $(CFNT_NS) --ignore-not-found=true

## ---- jobs -----
create_raw_jobs_cm:
	@echo "$(YELLOW)Creating raw-jobs ConfigMap from schema file...$(NC)"
	@kubectl create configmap raw-jobs-value \
		--from-file=schema=src/schemas/raw_jobs_schema.json \
		-n $(CFNT_NS) \
		--dry-run=client -o yaml | kubectl apply -f -

delete_raw_jobs_cm:
	@kubectl delete -f k8s/schemas/raw_jobs_cm.yaml -n $(CFNT_NS) --ignore-not-found=true

create_all_schemas: create_raw_orders_cm create_order_details_cm create_raw_jobs_cm
	@echo "$(YELLOW)Creating all schemas definitions in the Schema Registry...$(NC)"
	@kubectl apply -f k8s/schemas/raw_orders_schema.yaml -n $(CFNT_NS)
	@kubectl apply -f k8s/schemas/raw_jobs_schema.yaml -n $(CFNT_NS)
	@kubectl apply -f k8s/schemas/order_details_schema.yaml -n $(CFNT_NS)

delete_all_schemas:
	@kubectl delete -f k8s/schemas/raw_orders_schema.yaml -n $(CFNT_NS) --ignore-not-found=true
	@kubectl delete -f k8s/schemas/raw_jobs_schema.yaml -n $(CFNT_NS) --ignore-not-found=true
	@kubectl delete -f k8s/schemas/order_details_schema.yaml -n $(CFNT_NS) --ignore-not-found=true
	@echo "$(YELLOW)Permanently deleting subjects from Schema Registry...$(NC)"
	@curl -X DELETE "$(SR_URL)/subjects/raw-orders-value?permanent=true" 2>/dev/null || true
	@curl -X DELETE "$(SR_URL)/subjects/raw-jobs-value?permanent=true" 2>/dev/null || true
	@curl -X DELETE "$(SR_URL)/subjects/order-details-value?permanent=true" 2>/dev/null || true
	@echo "$(GREEN)Schema subjects permanently deleted$(NC)"
	
delete_all_cms: delete_raw_jobs_cm delete_raw_orders_cm delete_order_details_cm


delete_ns:
	@kubectl delete ns $(DEMO_NS)