CFNT_NS=confluent
FLCK_NS=flink
CERT_MGR_VERSION=v1.18.1
FLINK_OPERATOR_VERSION=1.11.0


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
	@colima start --cpu 6 --memory 24 --kubernetes

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
	fi

verify_cert_manager:
	@kubectl get pods -n cert-manager

use_flink_ns:
	@kubectl config set-context --current --namespace=$(FLCK_NS)


# ---------------------- Minio ----------------------
deploy_minio:
	@kubectl apply -f../MinIO/minio-dev.yaml 

minio_console:
	@kubectl port-forward pod/minio 9000 9090 -n minio-dev

verify_minio:
	@kubectl get pods -n minio-dev

	
# ---------------------- Confluent Platform  --------------------------------
install_cp: update_helm_confluent_repo deploy_cp_cfk verify_cp_cfk deploy_cp_cluster access_cp_console

update_helm_confluent_repo:
	@helm repo add confluentinc https://packages.confluent.io/helm
	@helm repo update

deploy_cp_cfk: 
	@helm upgrade --install confluent-operator confluentinc/confluent-for-kubernetes --set namespaced=false -n $(CFNT_NS)

verify_cp_cfk:
	@kubectl get pods -n $(CFNT_NS)

deploy_cp_cluster:
	@kubectl apply -f ../cfk/basic-kraft-cluster.yaml -n $(CFNT_NS)

access_cp_console:
	@kubectl port-forward service/controlcenter 9021:9021 -n $(CFNT_NS)

use_cp_ns:
	@kubectl config set-context --current --namespace=$(CFNT_NS)

port_forward_kafka_bootstrap:
	@kubectl port-forward service/kafka 9092:9092 -n $(CFNT_NS)

delete_cp_cluster:
	@kubectl delete -f ../cfk/basic-kraft-cluster.yaml -n $(CFNT_NS)

uninstall_cp_cluster:
	@helm uninstall confluent-operator -n $(CFNT_NS)


# ---------------------- Confluent Platform for Flink ----------------------

install_flink_kubernetes_operator:
	@helm upgrade --install--version "~1.120.0" cp-flink-kubernetes-operator confluentinc/flink-kubernetes-operator -n $(FLCK_NS)

deploy_cmf:
	@helm upgrade --install cmf --version "~2.0.0"  confluentinc/confluent-manager-for-apache-flink --namespace $(FLCK_NS) --set cmf.sql.production=false

install_cmf: deploy_apache_flink_operator deploy_cmf

verify_cmf:
	@kubectl get pods -n $(FLCK_NS)

port_forward_cmf:
	@kubectl port-forward svc/cmf-service 8084:8080 -n $(FLCK_NS)



create_flink_env:
	@confluent flink environment create env1 --url http://localhost:8084 --kubernetes-namespace $(FLCK_NS)

deploy_flink_demo_app:
	@confluent flink application create ../cmf/flinkapplication.json --environment env1 --url http://localhost:8084

undeploy_flink_demo_app:
	@confluent flink application delete basic-example --environment env1 --url http://localhost:8084

access_flink_console:
	@confluent flink application web-ui-forward basic-example --environment env1 --port 8090 --url http://localhost:8084

