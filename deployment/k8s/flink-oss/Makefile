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
	$(call ensure_ns, $(FLCK_NS))

use_flink_ns:
	@kubectl config set-context --current --namespace=$(FLCK_NS)

deploy_cert_manager:
	@kubectl get deployments cert-manager  -n cert-manager > /dev/null 2>&1;\
	if [ $$? -ne 0 ]; then \
		kubectl create -f https://github.com/jetstack/cert-manager/releases/download/$(CERT_MGR_VERSION)/cert-manager.yaml; \
	else \
		echo "cert manager already deployed"; \
	fi

# ---------------------- Minio ----------------------
deploy_minio:
	@kubectl apply -f../MinIO/minio-dev.yaml 

minio_console:
	@kubectl port-forward pod/minio 9000 9090 -n minio-dev

verify_minio:
	@kubectl get pods -n minio-dev

# ---------------------- Apache Flink ----------------------
update_helm_flink_repo:
	@helm repo remove flink-operator-repo
	@helm repo add flink-operator-repo https://downloads.apache.org/flink/flink-kubernetes-operator-$(FLINK_OPERATOR_VERSION)

deploy_apache_flink_operator: 
	@helm install flink-kubernetes-operator flink-operator-repo/flink-kubernetes-operator -n $(FLCK_NS)

uninstall_apache_flink_operator: 
	@helm uninstall flink-kubernetes-operator  flink-operator-repo/flink-kubernetes-operator -n $(FLCK_NS)

verify_flink:
	@kubectl get deployments -n $(FLCK_NS)
	@kubectl get pods -n $(FLCK_NS)
	@helm list -n $(FLCK_NS)

deploy_basic_flink_deployment:
	@kubectl apply -f basic_flink_deployment.yaml -n $(FLCK_NS)
	@kubectl get deployments -n $(FLCK_NS)
	@kubectl get pods -n $(FLCK_NS)
	POD_NAME=$$(kubectl get pods --namespace $(FLCK_NS) -l "app=basic-example" -o jsonpath="{.items[0].metadata.name}"); \
	echo $$POD_NAME; kubectl port-forward $$POD_NAME 8081:8081 -n $(FLCK_NS);

undeploy_basic_flink_deployment:
	@kubectl delete flinkdeployment/basic-example -n $(FLCK_NS)

deploy_jobmanager:
	@kubectl apply -f flink/flink-configuration-configmap.yaml  -n $(FLCK_NS)
	@kubectl apply -f flink/jobmanager-service.yaml  -n $(FLCK_NS)
	@kubectl apply -f flink/jobmanager-rest-service.yaml  -n $(FLCK_NS)
	@kubectl apply -f flink/jobmanager-session-deployment-non-ha.yaml  -n $(FLCK_NS)

deploy_taskmanager:
	@kubectl apply -f flink/taskmanager-session-deployment.yaml -n $(FLCK_NS)

flink_console:
	POD_NAME=$$(kubectl get pods --namespace $(FLCK_NS) -l "app=flink" -o jsonpath="{.items[0].metadata.name}"); \
	echo $$POD_NAME; kubectl port-forward $$POD_NAME 8082:8081 -n $(FLCK_NS);
	
# ------ OSS Kafka UI ---------
deploy_kafbat_ui:
	@kubectl apply -f cfk/kafbat-ui-deployment.yaml -n $(CFNT_NS);\
	export POD_NAME=$(kubectl get pods --namespace confluent -l "app=kafbat-ui" -o jsonpath="{.items[0].metadata.name}"); \
	echo "$(POD_NAME) and the Kafka cluster to configure is kafka.confluent.svc.cluster.local port 9071";\
	echo "then do a  port-forward on 8082: kubectl port-forward $(POD_NAME) 8082:8081"

delete_kafbat_ui:
	@helm delete -f cfk/kafbat-ui-deployment.yaml -n $(CFNT_NS)

tear_down: delete_kafbat_ui 