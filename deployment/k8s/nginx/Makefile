NGINX_VERSION=4.10.6
NGINX_NAMESPACE=nginx

BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
WHITE := \033[0;37m
NC := \033[0m

ensure_ns = \
	@kubectl get ns $1 >/dev/null 2>&1; \
	if [ $$? -ne 0 ]; then \
			kubectl create ns $1; \
	else \
			echo "$1 exists";\
	fi

help: ## Show this help message
	@echo "$(BLUE)NGinx Deployment Makefile$(NC)"
	@echo ""
	@echo "$(BLUE)Available targets:$(NC)"
	@awk 'BEGIN {FS = ":.*##"; printf ""} /^[a-zA-Z_-]+:.*?##/ { printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

update_helm_repo:
	@helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx  --force-update
	@helm repo update
	@echo "$(GREEN) Updated Helm Confluent repository$(NC)"

deploy: ## Deploy Nginx Ingress Controller
	$(call ensure_ns, $(NGINX_NAMESPACE))
	@helm upgrade --install ingress-nginx \
    ingress-nginx/ingress-nginx \
    --namespace ${NGINX_NAMESPACE} \
	--version ${NGINX_VERSION} \
    --set "controller.extraArgs.enable-ssl-passthrough=" \
    --set "controller.extraArgs.default-ssl-certificate=${NGINX_NAMESPACE}/ingress-cert" \
    --set "controller.extraArgs.enable-prometheus-metrics=" \
    --set "controller.extraArgs.enable-custom-metrics=" \
    --set "controller.extraArgs.enable-custom-metrics-pushgateway=" \
    --set "controller.extraArgs.enable-custom-metrics-pushgateway-namespace="

undeploy: ## Undeploy Nginx Ingress Controller
	@helm uninstall ingress-nginx -n ${NGINX_NAMESPACE}