# Payment Claims Enrichment - Kubernetes Makefile
# Convenience targets for managing Kubernetes deployment

NAMESPACE ?= el-demo
CFNT_NS ?= confluent
DEPLOYMENT_MODE ?= standalone
DOCKER_REGISTRY ?= 
IMAGE_VERSION ?= latest
CMF_URL ?= http://localhost:8084
ENV_NAME ?= dev-env
# Application Configuration
APP_NAME ?= external-lookup
DOCKER_IMAGE ?= payment-claims-enrichment
COMPUTE_POOL_ID ?= demos-pool
# Colors
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m

.PHONY: deploy status cleanup build push test validate

##@ Deployment


deploy: deploy-rbac ## Deploy the Flink application to Kubernetes
	@echo "$(BLUE)Deploying Payment Claims Enrichment...$(NC)"
	@kubectl apply -f k8s/configmap.yaml -n $(NAMESPACE)
	@kubectl apply -f k8s/minio-credentials-secret.yaml -n $(NAMESPACE)
	@kubectl apply -f k8s/flink-application.yaml -n $(NAMESPACE)

undeploy: ## Undeploy the Flink application from Kubernetes
	@echo "$(BLUE)Undeploying Payment Claims Enrichment...$(NC)"
	@kubectl delete -f k8s/flink-application.yaml -n $(NAMESPACE)

deploy-rbac: ## Deploy the RBAC resources
	@echo "$(BLUE)Deploying RBAC resources...$(NC)"
	@kubectl apply -f k8s/rbac.yaml -n $(NAMESPACE)

##@ Building


build:  ## Build the application JAR
	@echo "$(BLUE)Building application JAR with Maven...$(NC)"
	@echo "🔨 Running Maven clean package..."
	@mvn clean package -DskipTests
	@echo "$(GREEN)✅ Application JAR built successfully$(NC)"
	@ls -la target/*.jar


build-image: ## Build Docker image
	@echo "$(BLUE)Building Docker image...$(NC)"
	@echo "🏗️  Building Docker image using multi-stage Dockerfile..."
	@docker build -t $(DOCKER_IMAGE):latest .
	@echo "$(GREEN)✅ Docker image built successfully$(NC)"
	@docker images $(DOCKER_IMAGE):latest

test:  ## Run tests only
	@echo "$(BLUE)Running Maven tests...$(NC)"
	@mvn test
	@echo "$(GREEN)✅ Tests completed$(NC)"

clean:  ## Clean Maven build artifacts
	@echo "$(BLUE)Cleaning build artifacts...$(NC)"
	@mvn clean
	@echo "$(GREEN)✅ Build artifacts cleaned$(NC)"

build-and-deploy: build ## Build image and deploy
	@$(MAKE) build-image
	@$(MAKE) deploy

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

start_flink_shell: ## Start a Flink shell
	@confluent flink shell --compute-pool $(COMPUTE_POOL_ID) --environment $(ENV_NAME) --url $(CMF_URL)

##@ Testing

test-connectivity: ## Test external dependencies connectivity
	@echo "$(BLUE)Testing connectivity to external dependencies...$(NC)"
	@echo "Testing Kafka connectivity..."
	@kubectl run test-kafka --rm -i --tty --image=busybox \
		--restart=Never --namespace=$(CFNT_NS) \
		-- nc -zv kafka.confluent 9071 || true
	@echo "Testing ClaimDB connectivity..."
	@kubectl run test-claimdb --rm -i --tty --image=curlimages/curl \
		--restart=Never --namespace=$(NAMESPACE) \
		-- curl -f http://claimdb-svc.el-demo:8080/health || true


