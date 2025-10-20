CFNT_NS=confluent
FLCK_NS=confluent
MINIO_NS=minio-dev
CMF_URL=http://localhost:8084
DEMO_NS=rental
FLINK_ENV=dev-rental
FLINK_COMPUTE_POOL=rental-pool
FLINK_APP_NAME=rental-dsp

BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
WHITE := \033[0;37m
NC := \033[0m
BOLD := \033[1m

# GOALS: deploy the different Flink application
# Environment, compute pool and catalog are defined in the Makefile of the root directory as they are cross flink applications.

# PUBLIC commands
# ----------------------
help: ## Show this help message
	@echo "$(BLUE)Json Transformation Demo - Build & Deploy$(NC)"
	@echo ""
	@echo "$(BLUE)Available targets:$(NC)"
	@awk 'BEGIN {FS = ":.*##"; printf ""} /^[a-zA-Z_-]+:.*?##/ { printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

build: ## Build the Flink application
	@echo "$(YELLOW)Building Flink application...$(NC)"
	cd table_api && mvn package
	cd table_api && docker build -t $(FLINK_APP_NAME):latest .

deploy: ## Deploy the Flink application
	# kubectl apply -f k8s/flink-application.yaml -n $(DEMO_NS)
	confluent flink application create k8s/flink_application.json  --url $(CMF_URL) --environment $(FLINK_ENV)

status: ## Check the status of the Flink application
	@echo "$(WHITE)$(BOLD)Checking Flink application status...$(NC)"
	confluent  flink application describe $(FLINK_APP_NAME) --environment $(FLINK_ENV) --url $(CMF_URL)
	@echo "----------------------------------------"

start_flink_shell: ## Start Flink Shell connected to CP Flink Environment
	@osascript -e 'tell app "Terminal" to do script "confluent flink shell --environment $(FLINK_ENV) --compute-pool $(FLINK_COMPUTE_POOL) --url $(CMF_URL);"' -e 'tell application "Terminal" to set custom title of selected tab of the front window to "Flink Shell"'



# ---------------------- Flink ----------------------
use_flink_ns:
	@kubectl config set-context --current --namespace=$(FLCK_NS)

list_compute_pools:
	@confluent flink compute-pool list --environment $(FLINK_ENV) --url $(CMF_URL)

port_forward_cmf:
	@osascript -e 'tell app "Terminal" to do script "kubectl port-forward svc/cmf-service 8084:80 -n $(FLCK_NS)"' -e 'tell application "Terminal" to set custom title of selected tab of the front window to "CMF REST API"'




stop_port_forwards:
	@echo "Stopping all port forwards..."
	@pkill -f "kubectl.*port-forward" || true
	@echo "All port forwards stopped"
	@echo "Closing specific Terminal windows..."
	@osascript -e 'tell application "Terminal"' \
		-e 'set windowTitles to {"Minio Console", "CP Console", "CMF REST API", "Schema Registry", "Kafka Bootstrap"}' \
		-e 'if number of windows > 0 then' \
		-e '  repeat with w in windows' \
		-e '    try' \
		-e '      set winTitle to custom title of w' \
		-e '      if winTitle is in windowTitles then' \
		-e '        close w' \
		-e '      end if' \
		-e '    end try' \
		-e '  end repeat' \
		-e 'end if' \
		-e 'end tell'
	@echo "Port forward Terminal windows closed"

# ----- Flink Application -----
use_demo_ns:
	@kubectl config set-context --current --namespace=$(DEMO_NS)



flink_ui:
	@echo "$(YELLOW)Opening Flink UI...$(NC)"
	confluent flink application web-ui-forward $(FLINK_APP_NAME) --environment $(FLINK_ENV) --url $(CMF_URL)

undeploy:
	@echo "$(YELLOW)Deploying Flink application...$(NC)"
	confluent flink application delete $(FLINK_APP_NAME) --environment $(FLINK_ENV) --url $(CMF_URL) --force	