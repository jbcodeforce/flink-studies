# External Lookup Demo - Main Makefile
# This Makefile orchestrates building and deploying all components of the external lookup demo

# Environment variables
CFNT_NS=confluent
FLCK_NS=confluent
DEMO_NS=el-demo
MINIO_NS=minio-dev
CERT_MGR_VERSION=v1.18.1
FLINK_OPERATOR_VERSION=1.11.0
CMF_URL=http://localhost:8084
SR_URL=http://localhost:8081
ENV_NAME=dev-env
APP_NAME=external-lookup

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
.PHONY: help build build-all build-flink build-event-generator build-claimdb build-monitoring

help: ## Show this help message
	@echo "$(BLUE)External Lookup Demo - Build & Deploy$(NC)"
	@echo ""
	@echo "$(BLUE)Available targets:$(NC)"
	@awk 'BEGIN {FS = ":.*##"; printf ""} /^[a-zA-Z_-]+:.*?##/ { printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

##@ Building

build-all: build-flink build-event-generator build-claimdb build-monitoring ## Build all components

build-flink: ## Build Flink application
	@echo "$(BLUE)Building Flink application...$(NC)"
	@cd flink-app && make build
	@echo "$(GREEN)✅ Flink application built$(NC)"

build-event-generator: ## Build event generator
	@echo "$(BLUE)Building event generator...$(NC)"
	@cd event-generator && make build
	@echo "$(GREEN)✅ Event generator built$(NC)"

build-claimdb: ## Build ClaimDB API
	@echo "$(BLUE)Building ClaimDB API...$(NC)"
	@cd database && make build
	@echo "$(GREEN)✅ ClaimDB API built$(NC)"

build-monitoring: ## Build monitoring components
	@echo "$(BLUE)Building monitoring components...$(NC)"
	@cd monitoring && make build
	@echo "$(GREEN)✅ Monitoring components built$(NC)"

##@ Deployment

# --------- Deploy targets ---------
.PHONY: deploy deploy-all deploy-kafka-catalog deploy-flink deploy-event-generator deploy-claimdb deploy-monitoring

deploy-all: deploy-kafka-catalog \
 deploy-flink-app \
 deploy-event-generator \
 deploy-claimdb \
 deploy-monitoring ## Deploy all components

deploy-flink-app: ## Deploy Flink application
	@echo "$(BLUE)Deploying Flink application...$(NC)"
	@cd flink-app && make deploy
	@echo "$(GREEN)✅ Flink application deployed$(NC)"

deploy-kafka-catalog: ## Deploy the Flink Catalog
	@echo "$(BLUE)Deploying Kafka Catalog...$(NC)"
	@confluent flink catalog create k8s/kafka-catalog-cmf.json --url $(CMF_URL)


deploy-event-generator: ## Deploy event generator
	@echo "$(BLUE)Deploying event generator...$(NC)"
	@cd event-generator && make deploy
	@echo "$(GREEN)✅ Event generator deployed$(NC)"

deploy-claimdb: ## Deploy ClaimDB API
	@echo "$(BLUE)Deploying ClaimDB API...$(NC)"
	@cd database && make deploy
	@echo "$(GREEN)✅ ClaimDB API deployed$(NC)"

deploy-monitoring: ## Deploy monitoring components
	@echo "$(BLUE)Deploying monitoring components...$(NC)"
	@cd monitoring && make deploy
	@echo "$(GREEN)✅ Monitoring components deployed$(NC)"

# --------- Cleanup targets ---------
.PHONY: clean clean-all clean-flink clean-event-generator clean-claimdb clean-monitoring

clean-all: clean-flink-app clean-event-generator clean-claimdb clean-monitoring ## Clean all components

clean-flink-app: ## Clean Flink application
	@echo "$(BLUE)Cleaning Flink application...$(NC)"
	@cd flink-app && make clean
	@echo "$(GREEN)✅ Flink application cleaned$(NC)"

clean-event-generator: ## Clean event generator
	@echo "$(BLUE)Cleaning event generator...$(NC)"
	@cd event-generator && make clean
	@echo "$(GREEN)✅ Event generator cleaned$(NC)"

clean-claimdb: ## Clean ClaimDB API
	@echo "$(BLUE)Cleaning ClaimDB API...$(NC)"
	@cd database && make clean
	@echo "$(GREEN)✅ ClaimDB API cleaned$(NC)"

clean-monitoring: ## Clean monitoring components
	@echo "$(BLUE)Cleaning monitoring components...$(NC)"
	@cd monitoring && make clean
	@echo "$(GREEN)✅ Monitoring components cleaned$(NC)"

# --------- Status targets ---------
.PHONY: status status-all status-flink status-event-generator status-claimdb status-monitoring

status-all: status-flink status-event-generator status-claimdb status-monitoring ## Show status of all components

status-flink: ## Show Flink application status
	@echo "$(BLUE)Flink application status:$(NC)"
	@cd flink && make status
	@echo ""

status-event-generator: ## Show event generator status
	@echo "$(BLUE)Event generator status:$(NC)"
	@cd event-generator && make status
	@echo ""

status-claimdb: ## Show ClaimDB API status
	@echo "$(BLUE)ClaimDB API status:$(NC)"
	@cd database && make status
	@echo ""

status-monitoring: ## Show monitoring components status
	@echo "$(BLUE)Monitoring components status:$(NC)"
	@cd monitoring && make status
	@echo ""

##@ Information

list-resources: ## List all related Kubernetes resources
	@echo "$(BLUE)Resources in namespace: $(NAMESPACE)$(NC)"
	@kubectl get all -l app=$(APP_NAME) -n $(NAMESPACE) || true
	@echo ""
	@echo "$(BLUE)ConfigMaps:$(NC)"
	@kubectl get configmaps -l app=$(APP_NAME) -n $(NAMESPACE) || true
	@echo ""
	@echo "$(BLUE)Secrets:$(NC)"
	@kubectl get secrets -l app=$(APP_NAME) -n $(NAMESPACE) || true
	@echo ""
	@echo "$(BLUE)PersistentVolumeClaims:$(NC)"
	@kubectl get pvc -l app=$(APP_NAME) -n $(NAMESPACE) || true
	@echo ""
	@echo "$(BLUE)FlinkApplications:$(NC)"
	@kubectl get flinkapplication -l app=$(APP_NAME) -n $(NAMESPACE) || true




# --------- Service exposure ---------
expose-services: ## Expose all services via port-forward
	@echo "$(BLUE)Exposing services...$(NC)"
	make port-forward-cp-console
	make port-forward-cmf
	make port-forward-schema-registry
	make port-forward-kafka-bootstrap
	make port-forward-event-generator-metrics
	make port-forward-minio-console
	make port-forward-claimdb-api

# --------- Port forwarding ---------
port-forward-cp-console:
	@osascript -e 'tell app "Terminal" to do script "kubectl -n $(CFNT_NS) port-forward svc/controlcenter-ng 9021:9021"' -e 'tell application "Terminal" to set current settings of front window to settings set "Pro"'

port-forward-cmf:
	@osascript -e 'tell app "Terminal" to do script "kubectl port-forward svc/cmf-service 8084:80 -n $(FLCK_NS)"'

port-forward-schema-registry:
	@osascript -e 'tell app "Terminal" to do script "kubectl -n $(CFNT_NS) port-forward svc/schemaregistry 8081:8081"' -e 'tell application "Terminal" to set current settings of front window to settings set "Pro"'

port-forward-minio-console:
	@osascript -e 'tell app "Terminal" to do script "kubectl port-forward pod/minio 9090 9090 -n $(MINIO_NS)"' -e 'tell application "Terminal" to set custom title of selected tab of the front window to "Minio Console"'

port-forward-event-generator-metrics:
	@osascript -e 'tell app "Terminal" to do script "kubectl -n $(DEMO_NS) port-forward svc/event-generator-metrics 8090:8090"' -e 'tell application "Terminal" to set current settings of front window to settings set "Grass"'

port-forward-kafka-bootstrap:
	@echo "🔗 Starting Kafka port-forward..."
	@POD_NAME=$$(kubectl get pods -n $(CFNT_NS) -l app=kafka -o jsonpath='{.items[0].metadata.name}' 2>/dev/null); \
	if [ -n "$$POD_NAME" ]; then \
		echo "Port-forwarding to pod: $$POD_NAME"; \
		echo "✅ Kafka port-forward started on localhost:9092"; \
		osascript -e "tell app \"Terminal\" to do script \"kubectl -n $(CFNT_NS) port-forward pod/$$POD_NAME 9092:9092\"" -e 'tell application "Terminal" to set current settings of front window to settings set "Ocean"'; \
	else \
		echo "❌ No kafka pods found in namespace $(CFNT_NS)"; \
		echo "Available pods:"; \
		kubectl get pods -n $(CFNT_NS); \
	fi

port-forward-claimdb-api:
	@echo "Getting ClaimDB pod name and starting port-forward..."
	@POD_NAME=$$(kubectl get pods -n $(DEMO_NS) -l app=$(APP_NAME) -o jsonpath='{.items[0].metadata.name}' 2>/dev/null); \
	if [ -n "$$POD_NAME" ]; then \
		echo "Port-forwarding to pod: $$POD_NAME"; \
		osascript -e "tell app \"Terminal\" to do script \"kubectl -n $(DEMO_NS) port-forward pod/$$POD_NAME 8080:8080\"" -e 'tell application "Terminal" to set current settings of front window to settings set "Ocean"'; \
	else \
		echo "❌ No ClaimDB pods found in namespace $(DEMO_NS)"; \
		echo "Available pods:"; \
		kubectl get pods -n $(DEMO_NS); \
	fi

# --------- Namespace management ---------
create-ns:
	$(call ensure_ns, $(DEMO_NS))

use-demo-ns:
	@kubectl config set-context --current --namespace=$(DEMO_NS)

use-flink-ns:
	@kubectl config set-context --current --namespace=$(FLCK_NS)

use-cp-ns:
	@kubectl config set-context --current --namespace=$(CFNT_NS)

# --------- Kafka topics ---------
create-topics:
	@kubectl apply -f k8s/enriched-payments-topic.yaml
	@kubectl apply -f k8s/failed-payments-topic.yaml
	@kubectl apply -f k8s/payment-events-topic.yaml

list-kafka-topics:
	@kubectl get kafkatopics -n $(CFNT_NS)

# --------- Schema Registry ---------
list-schemas: ## List all schemas in Schema Registry
	@echo "📋 Listing schemas in Schema Registry..."
	@curl -X GET $(SR_URL)/subjects

describe-payment-event-schema: ## Describe payment event schema
	@echo "📋 Describing payment event schema..."
	@confluent schema-registry schema describe --subject payment-events-value --version latest --url $(SR_URL)

delete-payment-event-schema: ## Delete payment event schema from Schema Registry
	@echo "🗑️  Deleting payment event schema..."
	@confluent schema-registry schema delete --subject payment-events-value --version all --force --url $(SR_URL)
	@echo "✅ Payment event schema deleted"

validate_cmf: ## Validate Confluent Manager for Flink configuration
	@echo "🔍 Validating Confluent Manager for Flink configuration..."
	@kubectl get pods -n $(FLCK_NS) | grep Running | grep confluent-manager-for-apache-flink
	@kubectl get pods -n $(FLCK_NS) | grep Running | grep flink-kubernetes-operator
	@echo "✅ Confluent Manager for Flink configuration validated"

define_compute_pool: ## Define Compute Pool
	@echo "Defining Compute Pool..."
	@kubectl apply -f k8s/compute-pool-cmf.json -n $(FLCK_NS)
	@echo "✅ Compute Pool defined"

validate_cp_flink_artifacts: ## Validate Compute Pool Flink artifacts
	@echo "🔍 Validating Compute Pool Flink artifacts..."
	@confluent flink environment list --url $(CMF_URL)
	@echo ""
	@confluent flink compute-pool list --environment $(ENV_NAME) --url $(CMF_URL)
	@echo ""
	@confluent flink  catalog list --url $(CMF_URL)
	@echo "✅ Compute Pool Flink artifacts validated"

# --------- Demo management ---------
prepare_demo: set_docker_context \
		create_ns use_demo_ns validate_cmf \
		expose_services \
		create_topics \
		define_compute_pool \
		validate_cp_flink_artifacts ## Prepare demo environment on k8s


run_demo: ## Run the complete demo
	make expose_services
	make create_topics
	make deploy-all
	make consume_payment_events_cluster
	make consume_enriched_payments_cluster

# --------- Docker context ---------
start_colima: ## Start Colima with Kubernetes
	@colima start --cpu 8 --memory 24 --kubernetes

stop_colima: ## Stop Colima
	@colima stop

set_docker_context: ## Set Docker context to Colima
	@docker context use colima
	