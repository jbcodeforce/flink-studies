CFNT_NS=confluent
FLCK_NS=flink
CERT_MGR_VERSION=v1.18.1
FLINK_OPERATOR_VERSION=1.11.0
CMF_URL=http://localhost:8084
ENV_NAME=env1

# For Confluent Platform see Makefile in cfk folder

# ---------------------- Common functions ----------------------
ensure_ns = \
	@kubectl get ns $1 >/dev/null 2>&1; \
	if [ $$? -ne 0 ]; then \
			kubectl create ns $1; \
	else \
			echo "$1 exists";\
	fi


# ---------------------- Colima ----------------------
start_colima:
	@colima start --cpu 8 --memory 24 --kubernetes

stop_colima:
	@colima stop

set_docker_context:
	@docker context use colima

# ------- Common elements to install -------------
prepare: create_ns  deploy_minio verify_minio 

create_ns:
	$(call ensure_ns, $(FLCK_NS))

# ---------------------- Minio ----------------------
deploy_minio:
	@kubectl apply -f../MinIO/minio-dev.yaml 

port_forward_minio_console:
	@kubectl port-forward pod/minio 9000 9090 -n minio-dev

verify_minio:
	@kubectl get pods -n minio-dev

	
# ---------------------- Confluent Platform  --------------------------------
update_helm_confluent_repo:
	@helm repo add confluentinc https://packages.confluent.io/helm
	@helm repo update

# ---------------------- Confluent Manager for Flink ----------------------
install_cmf: prepare update_helm_confluent_repo install_flink_kubernetes_operator deploy_cmf

install_flink_kubernetes_operator:
	@helm upgrade --install cp-flink-kubernetes-operator --version "~1.120.0"  confluentinc/flink-kubernetes-operator --set watchNamespace="{flink, confluent}" -n $(FLCK_NS)

deploy_cmf:
	@helm upgrade --install cmf --version "~2.0.2"  confluentinc/confluent-manager-for-apache-flink --namespace $(FLCK_NS) --set cmf.sql.production=false --set cmf.sql.examples-catalog.enabled=true 



use_flink_ns:
	@kubectl config set-context --current --namespace=$(FLCK_NS)

verify_cmf:
	@kubectl get pods -n $(FLCK_NS)

port_forward_cmf:
	@osascript -e 'tell app "Terminal" to do script "kubectl port-forward svc/cmf-service 8084:80 -n $(FLCK_NS)"'

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

