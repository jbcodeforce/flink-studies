# Environment variables
CFNT_NS=confluent
FLCK_NS=confluent
DEMO_NS=rental
MINIO_NS=minio-dev
CMF_URL=http://localhost:8084
SR_URL=http://localhost:8081
ENV_NAME=dev-env
APP_NAME=json-xform
POOL_NAME=rental-pool

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
WHITE := \033[0;37m
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
	kubectl apply -f k8s/kafka_client_cm.yaml
	cd producer && make build 
	make create_all_topics
	make create_all_schemas
	make create_compute_pool
	cd cp-flink && make build

deploy_all: ## Deploy the demonstation components
	@echo "$(BLUE)Deploying demo...$(NC)"
	cd producer && make deploy
	@echo "Producer App Web Page should be visible at http://localhost:30080"


status_all: ## Validate the demo
	@echo "--------------------------------"
	@echo "$(BLUE)Validating demo...$(NC)"
	@echo "--------------------------------"
	cd producer && make status
	make status_all_topics
	make status_all_schemas
	make status_compute_pool
	@echo "✅ Demo status check complete!"

tear_down_demo: ## Tear down the demo
	@echo "$(BLUE)Tearing down demo...$(NC)"
	cd producer && make undeploy
	make delete_all_schemas
	make delete_all_cms
	make delete_all_topics

expose_services: ## Expose all the services needed for the demo
	@echo "$(BLUE)Exposing services...$(NC)"
	cd cp-flink && make port_forward_cp_console
	cd cp-flink && make port_forward_cmf
	cd cp-flink && make port_forward_schema_registry
	cd cp-flink && make port_forward_minio_console
	cd cp-flink && make port_forward_kafka_bootstrap

open_cp_console: ## Open Confluent Control Center console
	@echo "$(BLUE)Opening Confluent Control Center on http://localhost:9021 ...$(NC)"
	@open -a "Google Chrome" http://localhost:9021

# ------ PRIVATE TARGETS ------
# --------- Service exposure ---------


stop_port_forwards:
	cd cp-flink && make stop_port_forwards

# Complete setup for demo
setup_demo:
	@echo "✅ Demo setup complete!"
	@echo "📋 Next steps:"
	@echo "  🌐 Web Interface: http://localhost:30080"
	@echo "  📊 Job History Dashboard: http://localhost:30080/job-history"
	@echo "  🔗 Port-forward alternative: 'make port_forward_producer_api' then http://localhost:8080"
	@echo "  📚 API Docs: http://localhost:30080/docs"
	@echo "  🔍 Health Check: 'make test_api_health_nodeport'"


create_compute_pool:
	@echo "$(YELLOW)Creating compute pool...$(NC)"
	confluent flink compute-pool create k8s/compute_pool.yaml --environment $(ENV_NAME) --url $(CMF_URL)

delete_compute_pool:
	@echo "$(YELLOW)Deleting compute pool...$(NC)"
	confluent flink compute-pool delete $(POOL_NAME) --environment $(ENV_NAME) --url $(CMF_URL)

status_compute_pool:
	@echo "$(YELLOW)Checking compute pool...$(NC)"
	confluent flink compute-pool list --environment $(ENV_NAME) --url $(CMF_URL)
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
	@kubectl delete -f k8s/topics/raw_orders_topic.yaml -n $(CFNT_NS)
	@kubectl delete -f k8s/topics/raw_jobs_topic.yaml -n $(CFNT_NS)
	@kubectl delete -f k8s/topics/order_details_topic.yaml -n $(CFNT_NS)

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
		--from-file=schema=schemas/raw_orders_schema.json \
		-n $(CFNT_NS) \
		--dry-run=client -o yaml | kubectl apply -f -


delete_raw_orders_cm:
	@kubectl delete -f k8s/schemas/raw_orders_cm.yaml -n $(CFNT_NS)

create_order_details_cm:
	@echo "$(YELLOW)Creating order-details ConfigMap from schema file...$(NC)"
	@kubectl create configmap order-details-value \
		--from-file=schema=schemas/order_details_schema.json \
		-n $(CFNT_NS) \
		--dry-run=client -o yaml | kubectl apply -f -

delete_order_details_cm:
	@kubectl delete -f k8s/schemas/order_details_cm.yaml -n $(CFNT_NS)

## ---- jobs -----
create_raw_jobs_cm:
	@echo "$(YELLOW)Creating raw-jobs ConfigMap from schema file...$(NC)"
	@kubectl create configmap raw-jobs-value \
		--from-file=schema=schemas/raw-jobs-schema.json \
		-n $(CFNT_NS) \
		--dry-run=client -o yaml | kubectl apply -f -

delete_raw_jobs_cm:
	@kubectl delete -f k8s/schemas/raw_jobs_cm.yaml -n $(CFNT_NS)

create_all_schemas: create_raw_orders_cm create_order_details_cm create_raw_jobs_cm
	@echo "$(YELLOW)Creating all schemas...$(NC)"
	@kubectl apply -f k8s/schemas/raw-orders-schema.yaml -n $(CFNT_NS)
	@kubectl apply -f k8s/schemas/raw-jobs-schema.yaml -n $(CFNT_NS)
	@kubectl apply -f k8s/schemas/order-details-schema.yaml -n $(CFNT_NS)

delete_all_schemas:
	@kubectl delete -f k8s/schemas/raw-orders-schema.yaml -n $(CFNT_NS)
	@kubectl delete -f k8s/schemas/raw-jobs-schema.yaml -n $(CFNT_NS)
	@kubectl delete -f k8s/schemas/order-details-schema.yaml -n $(CFNT_NS)
	
delete_all_cms: delete_raw_jobs_cm delete_raw_orders_cm delete_order_details_cm


