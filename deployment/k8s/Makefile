
MINIO_NS=minio-dev
CERT_MGR_VERSION=v1.18.2
FLINK_OPERATOR_VERSION=1.11.0
CMF_URL=http://localhost:8084
CERT_MGR_NS=cert-manager

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
WHITE := \033[0;37m
NC := \033[0m
BOLD := \033[1m

help: ## Show this help message
	@echo "$(BLUE)Common K8S deployment Makefile$(NC)"
	@echo ""
	@echo "$(BLUE)Available targets:$(NC)"
	@awk 'BEGIN {FS = ":.*##"; printf ""} /^[a-zA-Z_-]+:.*?##/ { printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

# ---------------------- Common functions ----------------------
ensure_ns = \
	@kubectl get ns $1 >/dev/null 2>&1; \
	if [ $$? -ne 0 ]; then \
			kubectl create ns $1; \
	else \
			echo "$1 exists";\
	fi

# ---- Public commands ----------------------
start_orbstack: ## Start Orbstack Kubernetes cluster
	@orb start k8s

stop_orbstack: ## Stop Orbstack Kubernetes cluster
	@orb stop k8s


# ---------------------- Colima  ---------------------
start_colima: 
	@colima start --cpu 8 --memory 24 --kubernetes
	kubectl get ns

stop_colima: 
	@colima stop

set_docker_context: ## Set Docker context to Colima
	@docker context use orb

# Common deployment commands ----------------------
deploy: ## Deploy the certificate manager, minio and create the namespace
	@make create_ns
	@make deploy_cert_manager
	@make deploy_minio

status: ## Verify the status of the common elements
	@echo "$(BLUE)----------------------------------------$(NC)"
	@make verify_cert_manager
	@echo "$(BLUE)----------------------------------------$(NC)"
	@make verify_minio


port_forward_minio_console: ## Port forward the MinIO console
	@kubectl port-forward pod/minio 9000 9090 -n $(MINIO_NS)

undeploy: ## Undeploy the common elements
	@make undeploy_cert_manager
	@make undeploy_minio
# ------- Private commands -------------
create_ns:
	$(call ensure_ns, $(MINIO_NS))

deploy_cert_manager:
	@kubectl get deployments cert-manager  -n $(CERT_MGR_NS) > /dev/null 2>&1;\
	if [ $$? -ne 0 ]; then \
		kubectl create -f https://github.com/jetstack/cert-manager/releases/download/$(CERT_MGR_VERSION)/cert-manager.yaml; \
	else \
		echo "cert manager already deployed"; \
		kubectl get pods -n $(CERT_MGR_NS); \
	fi

upgrade_cert_manager:
	@kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/$(CERT_MGR_VERSION)/cert-manager.yaml

verify_cert_manager:
	@kubectl get pods -n $(CERT_MGR_NS)
	@echo "$(BLUE)Cert manager version: $(NC)"
	@kubectl get deployments cert-manager  -n $(CERT_MGR_NS) -o jsonpath="{.metadata.labels.app\.kubernetes\.io/version}"
	@echo ""
	@echo "$(BLUE)----------------------------------------$(NC)"



# ---------------------- Minio ----------------------
deploy_minio:
	@kubectl apply -f ./MinIO/minio-dev.yaml 
	@kubectl apply -f./MinIO/minio-credentials-secret.yaml

verify_minio:
	@kubectl get pods -n $(MINIO_NS)
	@echo "----------------------------------------"
	@kubectl get pods  -l app.kubernetes.io/app=minio  -n $(MINIO_NS) -o jsonpath="{.items[0].metadata.labels.app\.kubernetes\.io/version}"
	@echo ""

undeploy_minio:
	@kubectl delete -f ./MinIO/minio-dev.yaml
	@kubectl delete -f minio-credentials-secret.yaml