# Payment Claims Enrichment - Kubernetes Makefile
# Convenience targets for managing Kubernetes deployment

NAMESPACE ?= el-demo
DEPLOYMENT_MODE ?= standalone
BUILD_IMAGE ?= false
DOCKER_REGISTRY ?= 
IMAGE_VERSION ?= latest

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
	@echo "  $(GREEN)NAMESPACE$(NC)        Kubernetes namespace (default: flink)"
	@echo "  $(GREEN)DEPLOYMENT_MODE$(NC)  Deployment mode: standalone, operator, session (default: standalone)"
	@echo "  $(GREEN)BUILD_IMAGE$(NC)      Build Docker image before deployment (default: false)"
	@echo "  $(GREEN)DOCKER_REGISTRY$(NC)  Docker registry for image push"
	@echo "  $(GREEN)IMAGE_VERSION$(NC)    Image version tag (default: latest)"
	@echo ""
	@echo "$(BLUE)Examples:$(NC)"
	@echo "  make deploy NAMESPACE=production DEPLOYMENT_MODE=operator"
	@echo "  make build-and-deploy BUILD_IMAGE=true DOCKER_REGISTRY=myregistry.com"
	@echo "  make status NAMESPACE=staging"

##@ Deployment

deploy: ## Deploy the Flink application to Kubernetes
	@echo "$(BLUE)Deploying Payment Claims Enrichment...$(NC)"
	@./deploy.sh --mode $(DEPLOYMENT_MODE) --namespace $(NAMESPACE) \
		$(if $(filter true,$(BUILD_IMAGE)),--build) \
		$(if $(DOCKER_REGISTRY),--registry $(DOCKER_REGISTRY)) \
		$(if $(IMAGE_VERSION),--version $(IMAGE_VERSION))

deploy-with-port-forward: ## Deploy and setup port forwarding
	@echo "$(BLUE)Deploying with port forwarding...$(NC)"
	@./deploy.sh --mode $(DEPLOYMENT_MODE) --namespace $(NAMESPACE) --port-forward


##@ Building

build: ## Build the application JAR
	@echo "$(BLUE)Building application...$(NC)"
	@cd .. && ./build.sh

build-image: ## Build Docker image
	@echo "$(BLUE)Building Docker image...$(NC)"
	@cd .. && ./build.sh --docker

build-and-push: ## Build and push Docker image
	@echo "$(BLUE)Building and pushing Docker image...$(NC)"
	@if [ -z "$(DOCKER_REGISTRY)" ]; then \
		echo "$(RED)Error: DOCKER_REGISTRY must be set$(NC)"; \
		exit 1; \
	fi
	@cd .. && ./build.sh --docker
	@docker tag payment-claims-enrichment:latest $(DOCKER_REGISTRY)/payment-claims-enrichment:$(IMAGE_VERSION)
	@docker push $(DOCKER_REGISTRY)/payment-claims-enrichment:$(IMAGE_VERSION)
	@echo "$(GREEN)Image pushed: $(DOCKER_REGISTRY)/payment-claims-enrichment:$(IMAGE_VERSION)$(NC)"

build-and-deploy: ## Build image and deploy
	@$(MAKE) build-image
	@$(MAKE) deploy BUILD_IMAGE=true

##@ Monitoring

status: ## Check deployment status
	@./status.sh --namespace $(NAMESPACE)

status-detailed: ## Check detailed deployment status
	@./status.sh --namespace $(NAMESPACE) --detailed

status-watch: ## Watch deployment status
	@./status.sh --namespace $(NAMESPACE) --watch

logs: ## Show application logs
	@echo "$(BLUE)Showing logs for namespace: $(NAMESPACE)$(NC)"
	@kubectl logs -l app=payment-claims-enrichment -n $(NAMESPACE) -f

logs-jobmanager: ## Show JobManager logs
	@kubectl logs deployment/flink-jobmanager -n $(NAMESPACE) -f

logs-taskmanager: ## Show TaskManager logs
	@kubectl logs deployment/flink-taskmanager -n $(NAMESPACE) -f

port-forward: ## Setup port forwarding for Flink Web UI
	@echo "$(BLUE)Setting up port forwarding...$(NC)"
	@echo "Flink Web UI will be available at: http://localhost:8081"
	@kubectl port-forward service/flink-jobmanager 8081:8081 -n $(NAMESPACE)

##@ Management

scale-taskmanagers: ## Scale TaskManagers (usage: make scale-taskmanagers REPLICAS=4)
	@if [ -z "$(REPLICAS)" ]; then \
		echo "$(RED)Error: REPLICAS must be set (e.g., make scale-taskmanagers REPLICAS=4)$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)Scaling TaskManagers to $(REPLICAS) replicas...$(NC)"
	@kubectl scale deployment flink-taskmanager --replicas=$(REPLICAS) -n $(NAMESPACE)
	@kubectl rollout status deployment/flink-taskmanager -n $(NAMESPACE)

restart: ## Restart all deployments
	@echo "$(BLUE)Restarting deployments...$(NC)"
	@kubectl rollout restart deployment -l app=payment-claims-enrichment -n $(NAMESPACE)
	@kubectl rollout status deployment -l app=payment-claims-enrichment -n $(NAMESPACE)

update-config: ## Update ConfigMap and restart deployments
	@echo "$(BLUE)Updating configuration...$(NC)"
	@kubectl apply -f configmap.yaml -n $(NAMESPACE)
	@$(MAKE) restart

##@ Cleanup

cleanup: ## Remove all deployment resources
	@./cleanup.sh --namespace $(NAMESPACE)

cleanup-force: ## Force remove all resources without confirmation
	@./cleanup.sh --namespace $(NAMESPACE) --force

cleanup-keep-storage: ## Remove resources but keep storage
	@./cleanup.sh --namespace $(NAMESPACE) --keep-storage

cleanup-keep-namespace: ## Remove resources but keep namespace
	@./cleanup.sh --namespace $(NAMESPACE) --keep-namespace

##@ Development

dry-run: ## Show what would be deployed (dry run)
	@echo "$(BLUE)Dry run deployment...$(NC)"
	@./deploy.sh --dry-run --namespace $(NAMESPACE)

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
	@kubectl get pods -l app=payment-claims-enrichment -n $(NAMESPACE) -o wide
	@echo ""
	@echo "Events:"
	@kubectl get events -n $(NAMESPACE) --sort-by='.lastTimestamp' | tail -10
	@echo ""
	@echo "Problematic pods:"
	@kubectl get pods -l app=payment-claims-enrichment -n $(NAMESPACE) \
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
	@kubectl get all -l app=payment-claims-enrichment -n $(NAMESPACE) || true
	@echo ""
	@echo "$(BLUE)ConfigMaps:$(NC)"
	@kubectl get configmaps -l app=payment-claims-enrichment -n $(NAMESPACE) || true
	@echo ""
	@echo "$(BLUE)Secrets:$(NC)"
	@kubectl get secrets -l app=payment-claims-enrichment -n $(NAMESPACE) || true
	@echo ""
	@echo "$(BLUE)PersistentVolumeClaims:$(NC)"
	@kubectl get pvc -l app=payment-claims-enrichment -n $(NAMESPACE) || true

version: ## Show versions
	@echo "$(BLUE)Versions:$(NC)"
	@echo "kubectl: $$(kubectl version --client --short)"
	@echo "Kubernetes: $$(kubectl version --short | grep Server || echo 'Server version unavailable')"
	@echo "Application version: $$(grep 'app.version' configmap.yaml | cut -d':' -f2 | tr -d ' \"')"
