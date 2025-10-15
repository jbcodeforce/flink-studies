# Environment variables
CFNT_NS=confluent
FLCK_NS=confluent
DEMO_NS=el-demo
MINIO_NS=minio-dev
CMF_URL=http://localhost:8084
SR_URL=http://localhost:8081
ENV_NAME=dev-env
APP_NAME=json-xform

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
.PHONY: help build build-all

help: ## Show this help message
	@echo "$(BLUE)Json Transformation Demo - Build & Deploy$(NC)"
	@echo ""
	@echo "$(BLUE)Available targets:$(NC)"
	@awk 'BEGIN {FS = ":.*##"; printf ""} /^[a-zA-Z_-]+:.*?##/ { printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2 }' $(MAKEFILE_LIST)




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


open_cp_console: ## Open Confluent Control Center in Chrome on localhost:9021
	@echo "$(BLUE)Opening Confluent Control Center on http://localhost:9021 ...$(NC)"
	@open -a "Google Chrome" http://localhost:9021

