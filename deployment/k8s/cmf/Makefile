CFNT_NS=confluent
FLCK_NS=confluent
NS_LIST=$(FLCK_NS),el-demo,rental
CMF_VERSION="~2.1.0"
#CMF_VERSION="~2.0.0"
CONFLUENT_CMF_URL=http://localhost:8084
ENV_NAME=dev-env
FKO_VERSION="~1.130.0"
#FKO_VERSION="~1.120.0"
# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
WHITE := \033[0;37m
NC := \033[0m
BOLD := \033[1m

# For Confluent Platform see Makefile in cfk folder

# ---------------------- Common functions ----------------------
ensure_ns = \
	@kubectl get ns $1 >/dev/null 2>&1; \
	if [ $$? -ne 0 ]; then \
			kubectl create ns $1; \
	else \
			echo "$1 exists";\
	fi

help:
	@echo "$(BLUE)Confluent Manager for Flink Deployment Makefile$(NC)"
	@echo ""
	@echo "$(BLUE)Available targets:$(NC)"
	@awk 'BEGIN {FS = ":.*##"; printf ""} /^[a-zA-Z_-]+:.*?##/ { printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

# ------- Common elements to install -------------
deploy: create_ns  update_helm_confluent_repo  install_upgrade_fko deploy_cmf deploy_cmf_rest_class port_forward_cmf create_flink_env  ## Deploy the Confluent Manager for Flink.


status: verify_cmf verify_cmf_rest_class verify_flink_env list_kafka_catalogs ## Verify the Confluent Manager for Flink deployment.

undeploy:  delete_compute_pool delete_kafka_catalog delete_kafka_secret delete_env_secret_mapping ## Undeploy the Confluent Manager for Flink.

use_flink_ns: ## Use the Flink namespace.
	@kubectl config set-context --current --namespace=$(FLCK_NS)
	@echo "$(GREEN) Using namespace: $(FLCK_NS)$(NC)"




# ---- Private commands ------------
create_ns:
	$(call ensure_ns, $(FLCK_NS))
	$(call ensure_ns, el-demo)
	$(call ensure_ns, rental)
	@echo "$(GREEN) Created namespaces: $(NS_LIST)$(NC)"

# ---------------------- Confluent Manager for Flink ----------------------
update_helm_confluent_repo:
	@helm repo add confluentinc https://packages.confluent.io/helm
	@helm repo update

install_upgrade_fko:
	@helm upgrade --install cp-flink-kubernetes-operator --version $(FKO_VERSION) \
  confluentinc/flink-kubernetes-operator --set watchNamespaces="{$(NS_LIST)}"

verify_fko:
	@echo "$(BLUE)flink-kubernetes-operator version: $(NC)"
	@kubectl get deployments flink-kubernetes-operator  -n $(FLCK_NS) -o jsonpath="{.metadata.labels.app\.kubernetes\.io/version}"
	@echo ""
	@echo "$(BLUE)----------------------------------------$(NC)"

deploy_cmf:
	@kubectl apply -f cluster_role.yaml
	@kubectl apply -f flink_role.yaml
	@helm upgrade --install cmf --version $(CMF_VERSION)  confluentinc/confluent-manager-for-apache-flink --namespace $(FLCK_NS)  --values cmf_values.yaml 

deploy_cmf_rest_class:
	@kubectl apply -f cmf-rest-class.yaml

verify_cmf_rest_class:
	@echo "----------------------------------------"
	@kubectl get cmfrestclasses -n $(FLCK_NS)
	@echo "$(GREEN) Confluent Manager for Flink REST class verified$(NC)"

verify_cmf:
	@echo "----------------------------------------"
	@kubectl get pods -n $(FLCK_NS) | grep confluent-manager-for-apache-flink
	@echo "$(GREEN) Services:$(NC)"
	@kubectl get svc -n $(FLCK_NS) 
	@echo "$(GREEN) Confluent Manager for Flink verified$(NC)"
	@echo "$(GREEN) CMF values:$(NC)"
	@helm get values cmf -n $(FLCK_NS) -o yaml
	@echo "----------------------------------------"

verify_flink_env:
	@echo "----------------------------------------"
	curl -H "Content-type: application/yaml"  $(CONFLUENT_CMF_URL)/cmf/api/v1/environments/ | jq .
	@echo "$(GREEN) Flink environments verified$(NC)"

port_forward_cmf:
	@kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=confluent-manager-for-apache-flink -n $(FLCK_NS) --timeout=120s
	@osascript -e 'tell app "Terminal" to do script "kubectl port-forward svc/cmf-service 8084:80 -n $(FLCK_NS)"' -e 'tell application "Terminal" to set current settings of front window to settings set "Grass"'

create_flink_env:
	@confluent flink environment list --url $(CONFLUENT_CMF_URL) 2>/dev/null | grep -q "$(ENV_NAME)" && \
		echo "$(YELLOW)Environment $(ENV_NAME) already exists$(NC)" || \
		(confluent flink environment create $(ENV_NAME) --url $(CONFLUENT_CMF_URL) --kubernetes-namespace $(FLCK_NS) && \
		echo "$(GREEN)Environment $(ENV_NAME) created$(NC)")


create_compute_pool:
	@confluent flink compute-pool create ../cmf/compute_pool.json --environment $(ENV_NAME) --url $(CONFLUENT_CMF_URL)

list_compute_pools:
	@confluent flink compute-pool list --environment $(ENV_NAME) --url $(CONFLUENT_CMF_URL)

delete_compute_pool:
	@confluent flink compute-pool delete pool1 --environment $(ENV_NAME) --url $(CONFLUENT_CMF_URL)

create_kafka_catalog:
	@confluent flink catalog create ./kafka_catalog.json --url $(CONFLUENT_CMF_URL)

list_kafka_catalogs:
	@confluent flink catalog list --url $(CONFLUENT_CMF_URL)
	@echo "$(GREEN) Kafka catalogs verified$(NC)"

delete_kafka_catalog:
	@confluent flink catalog delete demo-cat --url $(CONFLUENT_CMF_URL)

create_kafka_secret:
	@curl -v -H "Content-Type: application/json" -X POST ${CONFLUENT_CMF_URL}/cmf/api/v1/secrets -d@../cmf/kafka_secret.json

create_env_secret_mapping:
	@curl -v -H "Content-Type: application/json" -X POST ${CONFLUENT_CMF_URL}/cmf/api/v1/environments/$(ENV_NAME)/secret-mappings -d@../cmf/env_secret_mapping.json

# ----------- Application ----------------------
deploy_flink_demo_app:
	@confluent flink application create ../flink-app-smoke-test/flinkapplication.json --environment $(ENV_NAME) --url $(CONFLUENT_CMF_URL)

undeploy_flink_demo_app:
	@confluent flink application delete basic-example --environment $(ENV_NAME) --url $(CONFLUENT_CMF_URL)


port_forward_flink_ui_console: ## Port forward the Flink console.
	@confluent flink application web-ui-forward basic-example --environment $(ENV_NAME) --port 8090 --url $(CONFLUENT_CMF_URL)


# ---------------------- Custom Flink Image with S3 Support ----------------------
DOCKER_REGISTRY?=jbcodeforce
IMAGE_NAME?=cp-flink-s3
IMAGE_TAG?=1.20.2-s3

build_flink_s3_image:
	@docker build -f Dockerfile.s3-enabled-alpine -t $(DOCKER_REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG) .
	@echo "Built image: $(DOCKER_REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)"

build_and_push_flink_s3_image: build_flink_s3_image
	@docker push $(DOCKER_REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)
	@echo "Pushed image: $(DOCKER_REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)"

# For local testing with colima/minikube
load_flink_s3_image_local: build_flink_s3_image
	@docker save $(DOCKER_REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG) | kubectl apply -f -

	