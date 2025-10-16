# Environment variables
CFNT_NS=confluent
FLCK_NS=confluent
DEMO_NS=rental
MINIO_NS=minio-dev
CMF_URL=http://localhost:8084
SR_URL=http://localhost:8081
ENV_NAME=dev-env
APP_NAME=json-xform

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m

# ---------------------- Common functions ----------------------
ensure_ns = \
	@kubectl get ns $1 >/dev/null 2>&1; \
	if [ $$? -ne 0 ]; then \
			kubectl create ns $1; \
	else \
			echo "namespace: $1 exists";\
	fi

# --------- Build targets ---------
.PHONY: help build-all deploy-all status-all

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
	kubectl apply -f k8s/kafka_client_cm.yaml
	cd producer && make build 


deploy_all: ## Deploy the demonstation components
	@echo "$(BLUE)Deploying demo...$(NC)"
	cd producer && make deploy
	@echo "Producer App Web Page should be visible at http://localhost:30080"


status_all: ## Validate the demo
	@echo "$(BLUE)Validating demo...$(NC)"
	cd producer && make status

tear_down_demo: ## Tear down the demo
	@echo "$(BLUE)Tearing down demo...$(NC)"
	cd producer && make undeploy

# ------ PRIVATE TARGETS ------
# --------- Service exposure ---------
expose-services: 
	@echo "$(BLUE)Exposing services...$(NC)"
	cd cp-flink && make port_forward_cp_console
	cd cp-flink && make port_forward_cmf
	cd cp-flink && make port_forward_schema-registry
	cd cp-flink && make port_forward_minio-console
	cd cp-flink && make port_forward_kafka_bootstrap



open_cp_console: 
	@echo "$(BLUE)Opening Confluent Control Center on http://localhost:9021 ...$(NC)"
	@open -a "Google Chrome" http://localhost:9021




# Complete setup for demo
setup_demo: create_topics create_cms create_schemas deploy_all_producers
	@echo "✅ Demo setup complete!"
	@echo "📋 Next steps:"
	@echo "  🌐 Web Interface: http://localhost:30080"
	@echo "  📊 Job History Dashboard: http://localhost:30080/job-history"
	@echo "  🔗 Port-forward alternative: 'make port_forward_producer_api' then http://localhost:8080"
	@echo "  📚 API Docs: http://localhost:30080/docs"
	@echo "  🔍 Health Check: 'make test_api_health_nodeport'"

# Clean up everything
cleanup_demo: delete_all_producers
	@echo "🧹 Demo cleanup complete!"

# ----- orders -----
create_raw_orders_cm:
	@echo "Creating raw-orders ConfigMap from schema file..."
	@kubectl create configmap raw-orders-value \
		--from-file=schema=schemas/raw-orders-schema.json \
		-n $(CFNT_NS) \
		--dry-run=client -o yaml | kubectl apply -f -

delete_raw_orders_cm:
	@kubectl delete -f k8s/raw_orders_cm.yaml -n $(CFNT_NS)