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

# PostgreSQL configuration for local development
PG_CONTAINER_NAME = claims-postgres
PG_PORT = 5432
PG_DB = claims
PG_USER = claims_user
PG_PASSWORD = claims_password

.PHONY: help build clean test push deploy status logs install dev-install run-api start-postgres stop-postgres init-postgres

# Default target
help: ## Show this help message
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

use_demo_ns:
	@kubectl config set-context --current --namespace=$(NAMESPACE)

start-postgres: ## Start PostgreSQL container for local development
	@echo "🚀 Starting PostgreSQL container..."
	@docker run --rm -d \
		--name $(PG_CONTAINER_NAME) \
		-e POSTGRES_DB=$(PG_DB) \
		-e POSTGRES_USER=$(PG_USER) \
		-e POSTGRES_PASSWORD=$(PG_PASSWORD) \
		-p $(PG_PORT):5432 \
		postgres:16-alpine
	@echo "⏳ Waiting for PostgreSQL to start..."
	@sleep 5
	@echo "✅ PostgreSQL is running on port $(PG_PORT)"

stop-postgres: ## Stop PostgreSQL container
	@echo "🛑 Stopping PostgreSQL container..."
	@docker stop $(PG_CONTAINER_NAME) || true
	@echo "✅ PostgreSQL stopped"

init-postgres: ## Initialize PostgreSQL schema and data
	@echo "🗃️  Initializing PostgreSQL schema and data..."
	@docker cp 01_create_schema.sql $(PG_CONTAINER_NAME):/tmp/
	@docker cp 02_insert_data.sql $(PG_CONTAINER_NAME):/tmp/
	@docker exec -i $(PG_CONTAINER_NAME) psql -U $(PG_USER) -d $(PG_DB) -f /tmp/01_create_schema.sql
	@docker exec -i $(PG_CONTAINER_NAME) psql -U $(PG_USER) -d $(PG_DB) -f /tmp/02_insert_data.sql
	@echo "✅ PostgreSQL initialized"

install: ## Install production dependencies using uv
	@echo "📦 Installing production dependencies..."
	@uv pip install --system -r <(uv pip compile pyproject.toml)

dev-install: ## Install development dependencies using uv
	@echo "📦 Installing development dependencies..."
	@uv pip install --system -r <(uv pip compile --all-extras pyproject.toml)

run-api: ## Run the FastAPI application locally
	@echo "🚀 Starting FastAPI application..."
	@DB_HOST=localhost \
	DB_PORT=$(PG_PORT) \
	DB_NAME=$(PG_DB) \
	DB_USER=$(PG_USER) \
	DB_PASSWORD=$(PG_PASSWORD) \
	uv run python -m uvicorn claimdb_api:app --host 0.0.0.0 --port 8080 --reload

dev: start-postgres init-postgres run-api ## Start everything needed for local development

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

stop: stop-postgres ## Stop all running containers
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

clean: stop ## Remove built images and containers
	@echo "🧹 Cleaning up..."
	@docker rmi $(IMAGE_NAME):$(IMAGE_TAG) || true
	@if [ ! -z "$(REGISTRY)" ]; then \
		docker rmi $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG) || true; \
	fi
	@echo "✅ Cleanup complete"

all: clean build test ## Clean, build, and test everything
	@echo "✅ Full build pipeline complete!"