CFNT_NS=confluent
CERT_MGR_VERSION=v1.18.1
DEMO_NS=el-demo
FLCK_NS=confluent


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
prepare: create_ns deploy_cert_manager verify_cert_manager

create_ns:
	$(call ensure_ns, $(CFNT_NS))


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


	
# ---------------------- Confluent Platform  --------------------------------
install_cp: update_helm_confluent_repo deploy_cert_manager create_ns deploy_cp_cfk verify_cp_cfk deploy_cp_cluster port_forward_cp_console

update_helm_confluent_repo:
	@helm repo add confluentinc https://packages.confluent.io/helm
	@helm repo update

deploy_cp_cfk: 
	@helm upgrade --install confluent-operator confluentinc/confluent-for-kubernetes --set namespaced=false --set kRaftEnabled=true  --set namespaceList="{$(CFNT_NS),$(FLCK_NS),$(DEMO_NS)}" --set enableCMFDay2Ops=true -n $(CFNT_NS)

verify_cp_cfk:
	@kubectl get pods -n $(CFNT_NS)

deploy_cp_cluster:
	@kubectl apply -f ../cfk/basic-kraft-cluster.yaml -n $(CFNT_NS)

use_cp_ns:
	@kubectl config set-context --current --namespace=$(CFNT_NS)

port_forward_cp_console:
	@osascript -e 'tell app "Terminal" to do script "kubectl -n $(CFNT_NS) port-forward svc/controlcenter-ng 9021:9021"'

delete_cp_cluster:
	@kubectl delete -f ../cfk/basic-kraft-cluster.yaml -n $(CFNT_NS)

uninstall_cp_cluster:
	@helm uninstall confluent-operator -n $(CFNT_NS)



