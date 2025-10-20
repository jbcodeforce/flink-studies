CFNT_NS=confluent
FLCK_NS=confluent
CMF_VERSION=~2.0.3
CERT_MGR_VERSION=v1.18.1
FLINK_OPERATOR_VERSION=1.11.0
CMF_URL=http://localhost:8084
ENV_NAME=dev-env

# For Confluent Platform see Makefile in cfk folder

# ---------------------- Common functions ----------------------
ensure_ns = \
	@kubectl get ns $1 >/dev/null 2>&1; \
	if [ $$? -ne 0 ]; then \
			kubectl create ns $1; \
	else \
			echo "$1 exists";\
	fi

# ------- Common elements to install -------------
prepare: create_ns  update_helm_confluent_repo install_cmf

create_ns:
	$(call ensure_ns, $(FLCK_NS))


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

	
# ---------------------- Confluent Platform  --------------------------------
update_helm_confluent_repo:
	@helm repo add confluentinc https://packages.confluent.io/helm
	@helm repo update

# ---------------------- Confluent Manager for Flink ----------------------
install_cmf: install_flink_kubernetes_operator deploy_cmf deploy_cmf_rest_class port_forward_cmf create_flink_env

install_flink_kubernetes_operator:
	@helm upgrade --install cp-flink-kubernetes-operator --version "~1.120.0"  confluentinc/flink-kubernetes-operator --set watchNamespace="{flink, confluent, el-demo}" -n $(FLCK_NS)

deploy_cmf:
	@helm upgrade --install cmf --version $(CMF_VERSION)  confluentinc/confluent-manager-for-apache-flink --namespace $(FLCK_NS) --set cmf.sql.production=false --set cmf.sql.examples-catalog.enabled=true 

deploy_cmf_rest_class:
	@kubectl apply -f cmf-rest-class.yaml

verify_cmf_rest_class:
	@kubectl get cmfrestclasses -n $(FLCK_NS)

use_flink_ns:
	@kubectl config set-context --current --namespace=$(FLCK_NS)

verify_cmf:
	@kubectl get pods -n $(FLCK_NS)

port_forward_cmf:
	@osascript -e 'tell app "Terminal" to do script "kubectl port-forward svc/cmf-service 8084:80 -n $(FLCK_NS)"' -e 'tell application "Terminal" to set current settings of front window to settings set "Grass"'

create_flink_env:
	@confluent flink environment create $(ENV_NAME) --url $(CMF_URL) --kubernetes-namespace $(FLCK_NS)

create_compute_pool:
	@confluent flink compute-pool create ../cmf/compute_pool.json --environment $(ENV_NAME) --url $(CMF_URL)

list_compute_pools:
	@confluent flink compute-pool list --environment $(ENV_NAME) --url $(CMF_URL)

delete_compute_pool:
	@confluent flink compute-pool delete pool1 --environment $(ENV_NAME) --url $(CMF_URL)

create_kafka_catalog:
	@confluent flink catalog create ../cmf/kafka_catalog.json --url $(CMF_URL)

delete_kafka_catalog:
	@confluent flink catalog delete demo-cat --url $(CMF_URL)

create_kafka_secret:
	@curl -v -H "Content-Type: application/json" -X POST ${CMF_URL}/cmf/api/v1/secrets -d@../cmf/kafka_secret.json

create_env_secret_mapping:
	@curl -v -H "Content-Type: application/json" -X POST ${CMF_URL}/cmf/api/v1/environments/$(ENV_NAME)/secret-mappings -d@../cmf/env_secret_mapping.json

# ----------- Application ----------------------
deploy_flink_demo_app:
	@confluent flink application create ../cmf/flinkapplication.json --environment $(ENV_NAME) --url $(CMF_URL)

undeploy_flink_demo_app:
	@confluent flink application delete basic-example --environment $(ENV_NAME) --url $(CMF_URL)

port_forward_flink_console:
	@confluent flink application web-ui-forward basic-example --environment $(ENV_NAME) --port 8090 --url $(CMF_URL)

status: verify_cmf verify_cmf_rest_class 