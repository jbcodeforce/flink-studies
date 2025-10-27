# Configuration
IMAGE_NAME ?= jbcodeforce/orders-producer
IMAGE_TAG ?= latest
REGISTRY ?=

# Kubernetes deployment file
K8S_DEPLOY_POD = k8s/producer_api_pod.yaml
K8S_DEPLOY_SVC = k8s/producer_api_svc.yaml
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
WHITE := \033[0;37m
NC := \033[0m
DEMO_NS = rental

.PHONY: help build deploy status

# GOALS: 
# Build the Web app Docker image and deploy it to Kubernetes
# Check the status of the application
# Undeploy the application
# ------ Public commands ------
help: ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n\nTargets:\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

build: ## Build the Docker image
	@echo "📦 Building Orders Producer Docker Image"
	@echo "Image: ${IMAGE_NAME}:${IMAGE_TAG}"
	docker build -t "${IMAGE_NAME}:${IMAGE_TAG}" .
	@if [ -n "$(REGISTRY)" ]; then \
		echo "🏷️  Tagging for registry: ${REGISTRY}"; \
		docker tag "${IMAGE_NAME}:${IMAGE_TAG}" "${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"; \
	fi
	@echo "✅ Build completed successfully!"
	@echo ""
	@echo "🎯 Next steps:"
	@echo "  Deploy to K8s:     make deploy"
	@echo "  Open the web browser: make open_web_ui_nodeport"
	@echo ""


deploy: ## Deploy to Kubernetes
	@echo "$(BLUE)Deploying to Kubernetes...$(NC)"
	kubectl apply -f $(K8S_DEPLOY_POD)
	kubectl apply -f $(K8S_DEPLOY_SVC)
	@echo "🌐 Waiting for pod to be ready..."
	@kubectl wait --for=condition=ready pod/producer-api -n $(DEMO_NS) --timeout=60s
	@echo "✅ Pod ready! Opening web interface..."
	@make open_web_ui_nodeport

status: ## Display information about the application
	@echo "--------------------------------"
	@echo "$(WHITE)Checking pod status in '$(DEMO_NS)' namespace:$(NC)"
	@kubectl get pods -n $(DEMO_NS) -l app=json-xform,component=api-server
	@echo "--------------------------------"
	@echo "$(WHITE)Checking service exposure$(NC)"
	@echo "--------------------------------"
	@kubectl get svc -n $(DEMO_NS) -l app=json-xform,component=api-server
	@echo "$(WHITE)Checking producer API health endpoint:$(NC)"
	@curl -f http://localhost:30080/health || (echo "$(RED)❌ Application health check failed.$(NC)" && exit 1)
	@echo "--------------------------------"

undeploy: ## Undeploy demonstration
	@echo "$(BLUE)Undeploying from Kubernetes...$(NC)"
	kubectl delete -f $(K8S_DEPLOY_POD) --ignore-not-found=true
	kubectl delete -f $(K8S_DEPLOY_SVC) --ignore-not-found=true

# ------ Private commands ------
# Access via NodePort (direct localhost access)
open_web_ui_nodeport:
	@echo "🌐 Opening web interface via NodePort..."
	@open http://localhost:30080

open_swagger_nodeport:
	@echo "📚 Opening Swagger UI via NodePort..."
	@open http://localhost:30080/docs

open_redoc_nodeport:
	@echo "📖 Opening ReDoc via NodePort..."
	@open http://localhost:30080/redoc


port_forward_producer_api:
	@osascript -e 'tell app "Terminal" to do script "kubectl -n $(CFNT_NS) port-forward svc/producer-api-service 8080:80"'
