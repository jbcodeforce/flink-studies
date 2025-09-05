CFNT_NS=confluent
FLCK_NS=flink
CERT_MGR_VERSION=v1.18.1
FLINK_OPERATOR_VERSION=1.11.0
CMF_URL=http://localhost:8084
ENV_NAME=env1


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
prepare: create_ns deploy_cert_manager verify_cert_manager deploy_minio verify_minio

create_ns:
	$(call ensure_ns, $(CFNT_NS))
	$(call ensure_ns, $(FLCK_NS))

deploy_cert_manager:
	@kubectl get deployments cert-manager  -n cert-manager > /dev/null 2>&1;\
	if [ $$? -ne 0 ]; then \
		kubectl create -f https://github.com/jetstack/cert-manager/releases/download/$(CERT_MGR_VERSION)/cert-manager.yaml; \
	else \
		echo "cert manager already deployed"; \
		kubectl get pods -n cert-manager; \
	fi

verify_cert_manager:
	@kubectl get pods -n cert-manager

# ---------------------- Minio ----------------------
deploy_minio:
	@kubectl apply -f../MinIO/minio-dev.yaml 

port_forward_minio_console:
	@kubectl port-forward pod/minio 9000 9090 -n minio-dev

verify_minio:
	@kubectl get pods -n minio-dev

	
# ---------------------- Confluent Platform  --------------------------------
install_cp: update_helm_confluent_repo deploy_cert_manager create_ns deploy_cp_cfk verify_cp_cfk deploy_cp_cluster port_forward_cp_console

update_helm_confluent_repo:
	@helm repo add confluentinc https://packages.confluent.io/helm
	@helm repo update

deploy_cp_cfk: 
	@helm upgrade --install confluent-operator confluentinc/confluent-for-kubernetes --set namespaced=false -n $(CFNT_NS)

verify_cp_cfk:
	@kubectl get pods -n $(CFNT_NS)

deploy_cp_cluster:
	@kubectl apply -f ../cfk/basic-kraft-cluster.yaml -n $(CFNT_NS)

use_cp_ns:
	@kubectl config set-context --current --namespace=$(CFNT_NS)

port_forward_cp_console:
	@osascript -e 'tell app "Terminal" to do script "kubectl -n $(CFNT_NS) port-forward svc/controlcenter-bootstrap-np 9021:9021"'

delete_cp_cluster:
	@kubectl delete -f ../cfk/basic-kraft-cluster.yaml -n $(CFNT_NS)

uninstall_cp_cluster:
	@helm uninstall confluent-operator -n $(CFNT_NS)


# ---------------------- Confluent Manager for Flink ----------------------

install_flink_kubernetes_operator:
	@helm upgrade --install cp-flink-kubernetes-operator --version "~1.120.0"  confluentinc/flink-kubernetes-operator --set watchNamespace="{flink, confluent}" -n $(FLCK_NS)

deploy_cmf:
	@helm upgrade --install cmf --version "~2.0.2"  confluentinc/confluent-manager-for-apache-flink --namespace $(FLCK_NS) --set cmf.sql.production=false --set cmf.sql.examples-catalog.enabled=true 

install_cmf: install_flink_kubernetes_operator deploy_cmf

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

