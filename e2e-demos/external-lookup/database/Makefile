# Makefile for claimdb External Lookup Database

# Configuration
IMAGE_NAME = demo-claimdb
IMAGE_TAG = latest
REGISTRY ?= 
NAMESPACE = el-demo
APP_NAME = external-lookup
# Docker build configuration
DOCKERFILE = Dockerfile
BUILD_CONTEXT = .

.PHONY: help build clean test push deploy status logs

# Default target
help: ## Show this help message
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

use_demo_ns:
	@kubectl config set-context --current --namespace=$(NAMESPACE)

build: ## Build the claimdb database Docker image
	@echo "🏗️  Building claimdb External Lookup Database Image..."
	@echo "Image: $(IMAGE_NAME):$(IMAGE_TAG)"
	@echo "Context: $(BUILD_CONTEXT)"
	@docker build \
		-t $(IMAGE_NAME):$(IMAGE_TAG) \
		-f $(DOCKERFILE) \
		$(BUILD_CONTEXT)
	@echo "✅ Successfully built $(IMAGE_NAME):$(IMAGE_TAG)"
	@echo ""
	@echo "📊 Image Information:"
	@docker images $(IMAGE_NAME):$(IMAGE_TAG) --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"


tag: ## Tag image for registry (use REGISTRY=your-registry.com make tag)
	@if [ -z "$(REGISTRY)" ]; then \
		echo "❌ REGISTRY not set. Use: make tag REGISTRY=your-registry.com"; \
		exit 1; \
	fi
	@docker tag $(IMAGE_NAME):$(IMAGE_TAG) $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)
	@echo "✅ Tagged as $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)"

push: tag ## Push image to registry (requires REGISTRY to be set)
	@docker push $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)
	@echo "✅ Pushed $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)"

test: ## Test the built image locally
	@echo "🧪 Testing claimdb image locally..."
	@echo "Starting container on port 8080..."
	@docker run --rm -d --name test-claimdb -p 8080:8080 $(IMAGE_NAME):$(IMAGE_TAG)
	@echo "Waiting for container to start..."
	@sleep 10
	@echo "Testing health endpoint..."
	@curl -f http://localhost:8080/health || (docker stop test-claimdb && exit 1)
	@echo "Testing claims endpoint..."
	@curl -f http://localhost:8080/claims/CLM-001 || (docker stop test-claimdb && exit 1)
	@docker stop test-claimdb
	@echo "✅ All tests passed!"

run: ## Run the image locally on port 8080
	@echo "🚀 Running claimdb container locally..."
	@docker run --rm -p 8080:8080 --name claimdb $(IMAGE_NAME):$(IMAGE_TAG)

run-detached: ## Run the image locally in detached mode
	@echo "🚀 Running claimdb container in background..."
	@docker run -d -p 8080:8080 --name claimdb $(IMAGE_NAME):$(IMAGE_TAG)
	@echo "✅ Container started. Access at http://localhost:8080"
	@echo "View logs: make logs"
	@echo "Stop container: make stop"

stop: ## Stop the running container
	@docker stop claimdb || true
	@docker rm claimdb || true
	@echo "✅ Container stopped"

logs: ## Show logs from the running container
	@docker logs -f claimdb

# Kubernetes deployment targets
deploy: ## Deploy to Kubernetes
	@echo "🚀 Deploying to Kubernetes namespace: $(NAMESPACE)"
	@kubectl apply -f k8s/persistent-volume.yaml
	@kubectl apply -f k8s/hostpath-sc.yaml
	@kubectl apply -f k8s/claimdb-configmap.yaml
	@kubectl apply -f k8s/claimdb-deployment.yaml
	@kubectl apply -f k8s/claimdb-service.yaml
	@echo "✅ Deployed to Kubernetes"

port-forward: ## Port forward the service
	@kubectl port-forward svc/claimdb-svc 8080:8080 -n $(NAMESPACE)


undeploy: ## Remove from Kubernetes
	@echo "🗑️  Removing from Kubernetes..."
	@kubectl delete -f k8s/ --ignore-not-found
	@echo "✅ Removed from Kubernetes"


status: ## Check Kubernetes deployment status
	@echo "📊 Checking deployment status in namespace: $(NAMESPACE)"
	@kubectl get pods -n $(NAMESPACE) -l app=$(APP_NAME)
	@kubectl get services -n $(NAMESPACE) -l app=$(APP_NAME)

clean: ## Remove built images and containers
	@echo "🧹 Cleaning up..."
	@docker stop claimdb || true
	@docker rm claimdb || true
	@docker rmi $(IMAGE_NAME):$(IMAGE_TAG) || true
	@if [ ! -z "$(REGISTRY)" ]; then \
		docker rmi $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG) || true; \
	fi
	@echo "✅ Cleanup complete"


all: clean build test ## Clean, build, and test everything
	@echo "✅ Full build pipeline complete!"
