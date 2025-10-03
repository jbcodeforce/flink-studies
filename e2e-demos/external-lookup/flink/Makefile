# Payment Claims Enrichment - Kubernetes Makefile
# Convenience targets for managing Kubernetes deployment

NAMESPACE ?= el-demo
DEPLOYMENT_MODE ?= standalone
BUILD_IMAGE ?= false
DOCKER_REGISTRY ?= 
IMAGE_VERSION ?= latest
CMF_URL ?= http://localhost:8084
ENV_NAME ?= dev-env
# Application Configuration
APP_NAME ?= external-lookup
DOCKER_IMAGE ?= payment-claims-enrichment

# Colors
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m

.PHONY: help deploy status cleanup build push test validate

# Default target
.DEFAULT_GOAL := help

help: ## Show this help message
	@echo "Payment Claims Enrichment - Kubernetes Deployment"
	@echo ""
	@echo "$(BLUE)Usage:$(NC)"
	@echo "  make <target> [VARIABLE=value]"
	@echo ""
	@echo "$(BLUE)Available targets:$(NC)"
	@awk 'BEGIN {FS = ":.*##"; printf ""} /^[a-zA-Z_-]+:.*?##/ { printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2 } /^##@/ { printf "\n$(BLUE)%s$(NC)\n", substr($$0, 5) }' $(MAKEFILE_LIST)
	@echo ""
	@echo "$(BLUE)Variables:$(NC)"
	@echo "  $(GREEN)NAMESPACE$(NC)        Kubernetes namespace (default: el-demo)"
	@echo "  $(GREEN)DEPLOYMENT_MODE$(NC)  Deployment mode: standalone, operator, session (default: standalone)"
	@echo "  $(GREEN)BUILD_IMAGE$(NC)      Build Docker image before deployment (default: false)"
	@echo "  $(GREEN)DOCKER_REGISTRY$(NC)  Docker registry for image push"
	@echo "  $(GREEN)IMAGE_VERSION$(NC)    Image version tag (default: latest)"
	@echo "  $(GREEN)APP_NAME$(NC)         Application name for labels and resources (default: payment-claims-enrichment)"
	@echo "  $(GREEN)DOCKER_IMAGE$(NC)     Docker image name (default: \$$APP_NAME)"
	@echo ""
	@echo "$(BLUE)Examples:$(NC)"
	@echo "  make deploy NAMESPACE=production DEPLOYMENT_MODE=operator"
	@echo "  make build-and-deploy BUILD_IMAGE=true DOCKER_REGISTRY=myregistry.com"
	@echo "  make status NAMESPACE=staging"

##@ Deployment

deploy-kafka-catalog: ## Deploy the Kafka Catalog
	@echo "$(BLUE)Deploying Kafka Catalog...$(NC)"
	@confluent flink catalog create k8s/kafka-catalog-cmf.json --url $(CMF_URL)

deploy: deploy-rbac deploy-kafka-catalog ## Deploy the Flink application to Kubernetes
	@echo "$(BLUE)Deploying Payment Claims Enrichment...$(NC)"
	@kubectl apply -f k8s/flink-application.yaml -n $(NAMESPACE)

deploy-compute-pool: ## Deploy the Compute Pool
	@echo "$(BLUE)Deploying Compute Pool...$(NC)"
	@confluent flink compute-pool create k8s/compute-pool-cmf.json  --environment $(ENV_NAME) --url $(CMF_URL)

list-compute-pools: ## List the Compute Pools
	@confluent flink compute-pool list --environment $(ENV_NAME) --url $(CMF_URL)

deploy-rbac: ## Deploy the RBAC resources
	@echo "$(BLUE)Deploying RBAC resources...$(NC)"
	@kubectl apply -f k8s/rbac.yaml -n $(NAMESPACE)

##@ Building

check-mvn: ## Check if Maven is available
	@echo "$(BLUE)Checking Maven installation...$(NC)"
	@command -v mvn >/dev/null 2>&1 || { \
		echo "$(RED)❌ Maven not found. Please install Maven 3.6+$(NC)"; \
		echo "$(YELLOW)Install with: brew install maven (macOS) or apt-get install maven (Ubuntu)$(NC)"; \
		exit 1; \
	}
	@echo "$(GREEN)✅ Maven found: $$(mvn --version | head -1)$(NC)"

build: check-mvn ## Build the application JAR
	@echo "$(BLUE)Building application JAR with Maven...$(NC)"
	@echo "🔨 Running Maven clean package..."
	@mvn clean package -DskipTests
	@echo "$(GREEN)✅ Application JAR built successfully$(NC)"
	@ls -la target/*.jar

build-with-tests: check-mvn ## Build the application JAR including tests
	@echo "$(BLUE)Building application JAR with tests...$(NC)"
	@echo "🧪 Running Maven clean package with tests..."
	@mvn clean package
	@echo "$(GREEN)✅ Application JAR built with tests$(NC)"

build-image: ## Build Docker image
	@echo "$(BLUE)Building Docker image...$(NC)"
	@echo "🏗️  Building Docker image using multi-stage Dockerfile..."
	@docker build -t $(DOCKER_IMAGE):latest .
	@echo "$(GREEN)✅ Docker image built successfully$(NC)"
	@docker images $(DOCKER_IMAGE):latest

test: check-mvn ## Run tests only
	@echo "$(BLUE)Running Maven tests...$(NC)"
	@mvn test
	@echo "$(GREEN)✅ Tests completed$(NC)"

clean: check-mvn ## Clean Maven build artifacts
	@echo "$(BLUE)Cleaning build artifacts...$(NC)"
	@mvn clean
	@echo "$(GREEN)✅ Build artifacts cleaned$(NC)"

build-and-push: ## Build and push Docker image
	@echo "$(BLUE)Building and pushing Docker image...$(NC)"
	@if [ -z "$(DOCKER_REGISTRY)" ]; then \
		echo "$(RED)Error: DOCKER_REGISTRY must be set$(NC)"; \
		exit 1; \
	fi
	@$(MAKE) build-image
	@docker tag $(DOCKER_IMAGE):latest $(DOCKER_REGISTRY)/$(DOCKER_IMAGE):$(IMAGE_VERSION)
	@docker push $(DOCKER_REGISTRY)/$(DOCKER_IMAGE):$(IMAGE_VERSION)
	@echo "$(GREEN)Image pushed: $(DOCKER_REGISTRY)/$(DOCKER_IMAGE):$(IMAGE_VERSION)$(NC)"

build-and-deploy: ## Build image and deploy
	@$(MAKE) build-image
	@$(MAKE) deploy BUILD_IMAGE=true

##@ Monitoring

status: ## Check deployment status
	@echo "$(BLUE)Checking deployment status in namespace: $(NAMESPACE)$(NC)"
	@echo ""
	@echo "$(BLUE)📋 Deployments:$(NC)"
	@kubectl get deployments -l app=$(APP_NAME) -n $(NAMESPACE) -o wide 2>/dev/null || echo "No deployments found"
	@echo ""
	@echo "$(BLUE)🏷️  Pods:$(NC)"
	@kubectl get pods -l app=$(APP_NAME) -n $(NAMESPACE) -o wide 2>/dev/null || echo "No pods found"
	@echo ""
	@echo "$(BLUE)📊 Services:$(NC)"
	@kubectl get services -l app=$(APP_NAME) -n $(NAMESPACE) 2>/dev/null || echo "No services found"
	@echo ""
	@echo "$(BLUE)💾 Storage:$(NC)"
	@kubectl get pvc -l app=$(APP_NAME) -n $(NAMESPACE) 2>/dev/null || echo "No PVCs found"
	@echo ""
	@echo "$(BLUE)🔍 Kafka Catalog:$(NC)"
	@confluent flink catalog list  --url $(CMF_URL)
	@echo ""
	@echo "$(BLUE)🔍 Compute Pools:$(NC)"
	@confluent flink compute-pool list --environment $(ENV_NAME) --url $(CMF_URL)
	@echo ""

status-detailed: ## Check detailed deployment status
	@echo "$(BLUE)Detailed deployment status in namespace: $(NAMESPACE)$(NC)"
	@echo ""
	@echo "$(BLUE)🔍 Pod Details:$(NC)"
	@kubectl describe pods -l app=$(APP_NAME) -n $(NAMESPACE) 2>/dev/null || echo "No pods found"
	@echo ""
	@echo "$(BLUE)📋 Recent Events:$(NC)"
	@kubectl get events -n $(NAMESPACE) --sort-by='.lastTimestamp' | tail -20 || echo "No events found"
	@echo ""
	@echo "$(BLUE)🔧 Resource Usage:$(NC)"
	@kubectl top pods -l app=$(APP_NAME) -n $(NAMESPACE) 2>/dev/null || echo "Metrics server not available"

status-watch: ## Watch deployment status
	@echo "$(BLUE)Watching deployment status in namespace: $(NAMESPACE)$(NC)"
	@echo "Press Ctrl+C to stop watching"
	@kubectl get pods -l app=$(APP_NAME) -n $(NAMESPACE) -w

logs: ## Show application logs
	@echo "$(BLUE)Showing logs for namespace: $(NAMESPACE)$(NC)"
	@kubectl logs -l app=$(APP_NAME) -n $(NAMESPACE) -f

logs-jobmanager: ## Show JobManager logs
	@kubectl logs deployment/flink-jobmanager -n $(NAMESPACE) -f

logs-taskmanager: ## Show TaskManager logs
	@kubectl logs deployment/flink-taskmanager -n $(NAMESPACE) -f

port-forward: ## Setup port forwarding for Flink Web UI
	@echo "$(BLUE)Setting up port forwarding...$(NC)"
	@echo "Flink Web UI will be available at: http://localhost:8081"
	@kubectl port-forward service/flink-jobmanager 8081:8081 -n $(NAMESPACE)

##@ Cleanup

cleanup: ## Remove all deployment resources
	@echo "$(BLUE)🗑️  Removing deployment resources in namespace: $(NAMESPACE)$(NC)"
	@echo ""
	@read -p "$(YELLOW)⚠️  Are you sure you want to delete all resources? (y/N): $(NC)" confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		echo "$(BLUE)Deleting FlinkApplication resources...$(NC)"; \
		kubectl delete flinkapplication -l app=$(APP_NAME) -n $(NAMESPACE) --ignore-not-found=true; \
		echo "$(BLUE)Deleting FlinkSessionJob resources...$(NC)"; \
		kubectl delete flinksessionjob -l app=$(APP_NAME) -n $(NAMESPACE) --ignore-not-found=true; \
		echo "$(BLUE)Deleting Deployments...$(NC)"; \
		kubectl delete deployments -l app=$(APP_NAME) -n $(NAMESPACE) --ignore-not-found=true; \
		echo "$(BLUE)Deleting Services...$(NC)"; \
		kubectl delete services -l app=$(APP_NAME) -n $(NAMESPACE) --ignore-not-found=true; \
		echo "$(BLUE)Deleting ConfigMaps...$(NC)"; \
		kubectl delete configmaps -l app=$(APP_NAME) -n $(NAMESPACE) --ignore-not-found=true; \
		echo "$(BLUE)Deleting Secrets...$(NC)"; \
		kubectl delete secrets -l app=$(APP_NAME) -n $(NAMESPACE) --ignore-not-found=true; \
		echo "$(BLUE)Deleting RBAC resources...$(NC)"; \
		kubectl delete serviceaccounts,roles,rolebindings -l app=$(APP_NAME) -n $(NAMESPACE) --ignore-not-found=true; \
		echo "$(BLUE)Deleting PersistentVolumeClaims...$(NC)"; \
		kubectl delete pvc -l app=$(APP_NAME) -n $(NAMESPACE) --ignore-not-found=true; \
		echo "$(GREEN)✅ Cleanup completed$(NC)"; \
	else \
		echo "$(YELLOW)Cleanup cancelled$(NC)"; \
	fi

cleanup-force: ## Force remove all resources without confirmation
	@echo "$(BLUE)🗑️  Force removing deployment resources in namespace: $(NAMESPACE)$(NC)"
	@echo "$(BLUE)Deleting FlinkApplication resources...$(NC)"
	@kubectl delete flinkapplication -l app=$(APP_NAME) -n $(NAMESPACE) --ignore-not-found=true
	@echo "$(BLUE)Deleting FlinkSessionJob resources...$(NC)"
	@kubectl delete flinksessionjob -l app=$(APP_NAME) -n $(NAMESPACE) --ignore-not-found=true
	@echo "$(BLUE)Deleting Deployments...$(NC)"
	@kubectl delete deployments -l app=$(APP_NAME) -n $(NAMESPACE) --ignore-not-found=true
	@echo "$(BLUE)Deleting Services...$(NC)"
	@kubectl delete services -l app=$(APP_NAME) -n $(NAMESPACE) --ignore-not-found=true
	@echo "$(BLUE)Deleting ConfigMaps...$(NC)"
	@kubectl delete configmaps -l app=$(APP_NAME) -n $(NAMESPACE) --ignore-not-found=true
	@echo "$(BLUE)Deleting Secrets...$(NC)"
	@kubectl delete secrets -l app=$(APP_NAME) -n $(NAMESPACE) --ignore-not-found=true
	@echo "$(BLUE)Deleting RBAC resources...$(NC)"
	@kubectl delete serviceaccounts,roles,rolebindings -l app=$(APP_NAME) -n $(NAMESPACE) --ignore-not-found=true
	@echo "$(BLUE)Deleting PersistentVolumeClaims...$(NC)"
	@kubectl delete pvc -l app=$(APP_NAME) -n $(NAMESPACE) --ignore-not-found=true
	@echo "$(GREEN)✅ Force cleanup completed$(NC)"

cleanup-keep-storage: ## Remove resources but keep storage
	@echo "$(BLUE)🗑️  Removing deployment resources (keeping storage) in namespace: $(NAMESPACE)$(NC)"
	@echo ""
	@read -p "$(YELLOW)⚠️  Remove resources but keep storage? (y/N): $(NC)" confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		echo "$(BLUE)Deleting FlinkApplication resources...$(NC)"; \
		kubectl delete flinkapplication -l app=$(APP_NAME) -n $(NAMESPACE) --ignore-not-found=true; \
		echo "$(BLUE)Deleting FlinkSessionJob resources...$(NC)"; \
		kubectl delete flinksessionjob -l app=$(APP_NAME) -n $(NAMESPACE) --ignore-not-found=true; \
		echo "$(BLUE)Deleting Deployments...$(NC)"; \
		kubectl delete deployments -l app=$(APP_NAME) -n $(NAMESPACE) --ignore-not-found=true; \
		echo "$(BLUE)Deleting Services...$(NC)"; \
		kubectl delete services -l app=$(APP_NAME) -n $(NAMESPACE) --ignore-not-found=true; \
		echo "$(BLUE)Deleting ConfigMaps...$(NC)"; \
		kubectl delete configmaps -l app=$(APP_NAME) -n $(NAMESPACE) --ignore-not-found=true; \
		echo "$(BLUE)Deleting Secrets...$(NC)"; \
		kubectl delete secrets -l app=$(APP_NAME) -n $(NAMESPACE) --ignore-not-found=true; \
		echo "$(BLUE)Deleting RBAC resources...$(NC)"; \
		kubectl delete serviceaccounts,roles,rolebindings -l app=$(APP_NAME) -n $(NAMESPACE) --ignore-not-found=true; \
		echo "$(YELLOW)⚠️  Keeping PersistentVolumeClaims (storage preserved)$(NC)"; \
		echo "$(GREEN)✅ Cleanup completed (storage preserved)$(NC)"; \
	else \
		echo "$(YELLOW)Cleanup cancelled$(NC)"; \
	fi

cleanup-keep-namespace: ## Remove resources but keep namespace
	@echo "$(BLUE)🗑️  Removing deployment resources (keeping namespace) in namespace: $(NAMESPACE)$(NC)"
	@echo ""
	@read -p "$(YELLOW)⚠️  Remove resources but keep namespace? (y/N): $(NC)" confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		echo "$(BLUE)Deleting FlinkApplication resources...$(NC)"; \
		kubectl delete flinkapplication -l app=$(APP_NAME) -n $(NAMESPACE) --ignore-not-found=true; \
		echo "$(BLUE)Deleting FlinkSessionJob resources...$(NC)"; \
		kubectl delete flinksessionjob -l app=$(APP_NAME) -n $(NAMESPACE) --ignore-not-found=true; \
		echo "$(BLUE)Deleting Deployments...$(NC)"; \
		kubectl delete deployments -l app=$(APP_NAME) -n $(NAMESPACE) --ignore-not-found=true; \
		echo "$(BLUE)Deleting Services...$(NC)"; \
		kubectl delete services -l app=$(APP_NAME) -n $(NAMESPACE) --ignore-not-found=true; \
		echo "$(BLUE)Deleting ConfigMaps...$(NC)"; \
		kubectl delete configmaps -l app=$(APP_NAME) -n $(NAMESPACE) --ignore-not-found=true; \
		echo "$(BLUE)Deleting Secrets...$(NC)"; \
		kubectl delete secrets -l app=$(APP_NAME) -n $(NAMESPACE) --ignore-not-found=true; \
		echo "$(BLUE)Deleting RBAC resources...$(NC)"; \
		kubectl delete serviceaccounts,roles,rolebindings -l app=$(APP_NAME) -n $(NAMESPACE) --ignore-not-found=true; \
		echo "$(BLUE)Deleting PersistentVolumeClaims...$(NC)"; \
		kubectl delete pvc -l app=$(APP_NAME) -n $(NAMESPACE) --ignore-not-found=true; \
		echo "$(YELLOW)⚠️  Keeping namespace: $(NAMESPACE)$(NC)"; \
		echo "$(GREEN)✅ Cleanup completed (namespace preserved)$(NC)"; \
	else \
		echo "$(YELLOW)Cleanup cancelled$(NC)"; \
	fi

##@ Development

dry-run: ## Show what would be deployed (dry run)
	@echo "$(BLUE)Dry run deployment in namespace: $(NAMESPACE)$(NC)"
	@echo ""
	@echo "$(BLUE)📋 Kubernetes manifests that would be applied:$(NC)"
	@for file in k8s/*.yaml; do \
		if [ -f "$$file" ]; then \
			echo "$(YELLOW)🔍 Validating: $$file$(NC)"; \
			kubectl apply --dry-run=client -f "$$file" -n $(NAMESPACE) || exit 1; \
		fi; \
	done
	@echo ""
	@echo "$(GREEN)✅ All manifests are valid for deployment$(NC)"

validate: ## Validate Kubernetes manifests
	@echo "$(BLUE)Validating Kubernetes manifests...$(NC)"
	@for file in *.yaml; do \
		echo "Validating $$file..."; \
		kubectl apply --dry-run=client -f $$file || exit 1; \
	done
	@echo "$(GREEN)All manifests are valid$(NC)"

lint: ## Lint Kubernetes manifests
	@echo "$(BLUE)Linting Kubernetes manifests...$(NC)"
	@command -v kubeval >/dev/null 2>&1 || { \
		echo "$(YELLOW)kubeval not found, skipping validation$(NC)"; \
		echo "Install with: go install github.com/instrumenta/kubeval@latest"; \
		exit 0; \
	}
	@for file in *.yaml; do \
		echo "Linting $$file..."; \
		kubeval $$file; \
	done

debug: ## Debug deployment issues
	@echo "$(BLUE)Debugging deployment...$(NC)"
	@echo "Pods:"
	@kubectl get pods -l app=$(APP_NAME) -n $(NAMESPACE) -o wide
	@echo ""
	@echo "Events:"
	@kubectl get events -n $(NAMESPACE) --sort-by='.lastTimestamp' | tail -10
	@echo ""
	@echo "Problematic pods:"
	@kubectl get pods -l app=$(APP_NAME) -n $(NAMESPACE) \
		--field-selector=status.phase!=Running,status.phase!=Succeeded

shell-jobmanager: ## Open shell in JobManager pod
	@kubectl exec -it deployment/flink-jobmanager -n $(NAMESPACE) -- bash

shell-taskmanager: ## Open shell in TaskManager pod
	@kubectl exec -it deployment/flink-taskmanager -n $(NAMESPACE) -- bash

##@ Testing

test-connectivity: ## Test external dependencies connectivity
	@echo "$(BLUE)Testing connectivity to external dependencies...$(NC)"
	@echo "Testing Kafka connectivity..."
	@kubectl run test-kafka --rm -i --tty --image=busybox \
		--restart=Never --namespace=$(NAMESPACE) \
		-- nc -zv kafka.confluent 9092 || true
	@echo "Testing DuckDB connectivity..."
	@kubectl run test-duckdb --rm -i --tty --image=curlimages/curl \
		--restart=Never --namespace=$(NAMESPACE) \
		-- curl -f http://duckdb-external-lookup.el-demo:8080/health || true

test-smoke: ## Run smoke tests after deployment
	@echo "$(BLUE)Running smoke tests...$(NC)"
	@echo "Checking if Flink job is running..."
	@kubectl exec deployment/flink-jobmanager -n $(NAMESPACE) -- \
		/opt/flink/bin/flink list | grep RUNNING || \
		echo "$(YELLOW)No running jobs found$(NC)"

load-test: ## Scale up event generator for load testing
	@echo "$(BLUE)Starting load test...$(NC)"
	@kubectl scale deployment event-generator --replicas=3 -n el-demo || \
		echo "$(YELLOW)Event generator not found in el-demo namespace$(NC)"

##@ Information

info: ## Show deployment information
	@echo "$(BLUE)Deployment Information$(NC)"
	@echo "Namespace: $(NAMESPACE)"
	@echo "Deployment Mode: $(DEPLOYMENT_MODE)"
	@echo "Build Image: $(BUILD_IMAGE)"
	@echo "Docker Registry: $(DOCKER_REGISTRY)"
	@echo "Image Version: $(IMAGE_VERSION)"
	@echo ""
	@echo "$(BLUE)Current Context:$(NC)"
	@kubectl config current-context
	@echo ""
	@echo "$(BLUE)Cluster Info:$(NC)"
	@kubectl cluster-info

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

version: ## Show versions
	@echo "$(BLUE)Versions:$(NC)"
	@echo "kubectl: $$(kubectl version --client --short)"
	@echo "Kubernetes: $$(kubectl version --short | grep Server || echo 'Server version unavailable')"
	@echo "Application version: $$(grep 'app.version' configmap.yaml | cut -d':' -f2 | tr -d ' \"')"
