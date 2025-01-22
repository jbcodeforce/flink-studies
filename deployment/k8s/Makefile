CFNT_NS=confluent
FLCK_NS=flink
CERT_MGR_VERSION=v1.16.2

prepare: create_ns install_operators

start_minikube:
	@minikube start --cpus 4 --memory 10g --driver docker

ensure_ns = \
	@kubectl get ns $1 >/dev/null 2>&1; \
	if [ $$? -ne 0 ]; then \
			kubectl create ns $1; \
	else \
			echo "$1 exists";\
	fi

create_ns:
	$(call ensure_ns, $(CFNT_NS))
	$(call ensure_ns, $(FLCK_NS))

use_flink_ns:
	@kubectl config set-context --current --namespace=$(FLCK_NS)

use_cp_ns:
	@kubectl config set-context --current --namespace=$(CFNT_NS)

install_operators: create_ns deploy_cert_manager deploy_cp_flink_operator deploy_cp_operator

deploy_cert_manager:
	@kubectl get deployments cert-manager  -n cert-manager > /dev/null 2>&1;\
	if [ $$? -ne 0 ]; then \
		kubectl create -f https://github.com/jetstack/cert-manager/releases/download/$(CERT_MGR_VERSION)/cert-manager.yaml; \
	else \
		echo "cert manager already deployed"; \
	fi

deploy_oss_flink_operator: 
	@helm install flink-kubernetes-operator flink-operator-repo/flink-kubernetes-operator -n $(FLCK_NS)

deploy_cp_flink_operator: 
	@helm install cp-flink-kubernetes-operator confluentinc/flink-kubernetes-operator -n $(FLCK_NS)

define_flink_cluster:
	@kubectl apply -f 

deploy_cp_operator:
	@helm install confluent-operator confluentinc/confluent-for-kubernetes --set namespaceList="{confluent,cfk}" --set namespaced=true -n $(CFNT_NS)

deploy_cp_cluster:
	@kubectl apply -f cfk/basic-kraft-cluster.yaml -n $(CFNT_NS)

delete_cp_cluster:
	@kubectl delete -f cfk/basic-kraft-cluster.yaml -n $(CFNT_NS)

display_operators:
	@kubectl get pods -n $(CFNT_NS)
	@kubectl get pods -n $(FLCK_NS)

display_kafka_endpoints:
	@kubectl confluent http-endpoints

deploy_kafbat_ui:
	@kubectl apply -f cfk/kafbat-ui-deployment.yaml -n $(CFNT_NS);\
	export POD_NAME=$(kubectl get pods --namespace confluent -l "app=kafbat-ui" -o jsonpath="{.items[0].metadata.name}"); \
	echo "$(POD_NAME) and the Kafka cluster to configure is kafka.confluent.svc.cluster.local port 9071";\
	echo "then do a port-forward on 8080: k port-forward podi 8080"

delete_kafbat_ui:
	@helm delete -f cfk/kafbat-ui-deployment.yaml -n $(CFNT_NS)

undeploy_cp_cluster:
	@kubectl delete -f cfk/basic-kraft-cluster.yaml -n $(CFNT_NS)

tear_down: delete_kafbat_ui