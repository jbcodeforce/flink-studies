CFNT_NS=confluent
DEMO_NS=el-demo,rental

# ---------------------- Confluent Platform  --------------------------------
# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
WHITE := \033[0;37m
NC := \033[0m
BOLD := \033[1m
# ---------------------- Common functions ----------------------
ensure_ns = \
	@kubectl get ns $1 >/dev/null 2>&1; \
	if [ $$? -ne 0 ]; then \
			kubectl create ns $1; \
	else \
			echo "$1 exists";\
	fi

.PHONY: help deploy status

help: ## Show this help message
	@echo "$(BLUE)Confluent Platform CFK Deployment Makefile$(NC)"
	@echo ""
	@echo "$(BLUE)Available targets:$(NC)"
	@awk 'BEGIN {FS = ":.*##"; printf ""} /^[a-zA-Z_-]+:.*?##/ { printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

# ------- Common elements to install -------------
deploy: create_ns update_helm_confluent_repo upgrade_crds  deploy_cp_cfk verify_cp_cfk deploy_cp_cluster ## Deploy the Confluent Platform.

use_confluent_ns: ## Use the confluent namespace	
	@kubectl config set-context --current --namespace=$(CFNT_NS)
	@echo "$(GREEN) Using namespace: $(CFNT_NS)$(NC)"

status: use_confluent_ns verify_cp_cfk verify_kraft verify_kafka verify_controlcenter verify_schemaregistry	## Get deployment status.


undeploy: delete_cp_cluster uninstall_cp_cfk ## Undeploy the Confluent Platform.

port_forward_cp_console: ## Port forward the Confluent Platform console.
	@osascript -e 'tell app "Terminal" to do script "kubectl -n $(CFNT_NS) port-forward svc/controlcenter-ng 9021:9021"'

port_forward_schema_registry: ## Port forward the Schema Registry
	@osascript -e 'tell app "Terminal" to do script "kubectl -n $(CFNT_NS) port-forward svc/schemaregistry 8081:8081"' -e 'tell application "Terminal" to set custom title of selected tab of the front window to "Schemma Registry"'

# ---- private commands ------------
create_ns:
	$(call ensure_ns, $(CFNT_NS))

update_helm_confluent_repo:
	@helm repo add confluentinc https://packages.confluent.io/helm --force-update
	@helm repo update
	@echo "$(GREEN) Updated Helm Confluent repository$(NC)"

upgrade_crds:
	helm show crds confluentinc/confluent-for-kubernetes | kubectl apply --server-side=true -f -
	@echo "$(GREEN) Upgraded Confluent Platform CRDs$(NC)"

deploy_cp_cfk: 
	@helm upgrade --install confluent-operator confluentinc/confluent-for-kubernetes --set namespaced=false --set kRaftEnabled=true  --set namespaceList="{$(CFNT_NS),$(FLCK_NS),$(DEMO_NS)}" --set enableCMFDay2Ops=true -n $(CFNT_NS)
	@echo "$(GREEN) Deployed Confluent Platform CFK$(NC)"

deploy_cp_cluster:
	@kubectl apply -f control-center.yaml -n $(CFNT_NS)
	@kubectl apply -f kafka-cluster.yaml -n $(CFNT_NS)
	@kubectl apply -f kraft-controller.yaml -n $(CFNT_NS)
	@kubectl apply -f schema-registry.yaml -n $(CFNT_NS)
	@echo "$(GREEN) Deployed Confluent Platform Kafka Cluster$(NC)"

delete_cp_cluster:
	@kubectl delete -f schema-registry.yaml -n $(CFNT_NS)
	@kubectl delete -f control-center.yaml -n $(CFNT_NS)
	@kubectl delete -f kafka-cluster.yaml -n $(CFNT_NS)
	@kubectl delete -f kraft-controller.yaml -n $(CFNT_NS)
	@echo "$(GREEN) Deleted Confluent Platform Kafka Cluster$(NC)"

uninstall_cp_cfk:
	@helm uninstall confluent-operator -n $(CFNT_NS)
	@echo "$(GREEN) Uninstalled Confluent Platform CFK$(NC)"


verify_cp_cfk:
	@echo "----------------------------------------"
	@kubectl get pods -n $(CFNT_NS)
	@echo "----------------------------------------"

verify_kraft:
	@kubectl describe KRaftController kraftcontroller  -n $(CFNT_NS)
	@echo "----------------------------------------"k

verify_kafka:
	@kubectl describe Kafka kafka -n $(CFNT_NS)
	@echo "----------------------------------------"

verify_controlcenter:
	@kubectl describe ControlCenter controlcenter-ng -n $(CFNT_NS)
	@echo "----------------------------------------"

verify_schemaregistry:
	@kubectl describe SchemaRegistry schemaregistry -n $(CFNT_NS)
	@echo "----------------------------------------"

