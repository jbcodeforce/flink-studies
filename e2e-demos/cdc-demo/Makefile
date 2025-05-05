CFNT_NS=confluent
FLCK_NS=flink
CERT_MGR_VERSION=v1.17.1
FLINK_OPERATOR_VERSION=1.11.0

prepare: create_ns install_operators

# ---------------------- Colima ----------------------
start_colima:
	@colima start --cpu 4 --memory 10 --kubernetes

stop_colima:
	@colima stop


ensure_ns = \
	@kubectl get ns $1 >/dev/null 2>&1; \
	if [ $$? -ne 0 ]; then \
			kubectl create ns $1; \
	else \
			echo "$1 exists";\
	fi

verify_installation:
	@helm list
	@echo "Certification managers  -> should get 3 pods"
	@kubectl get pods -n cert-manager
	@echo "Apache Flink Operator  -> should get 3 pods"
	@kubectl get pods -n flink
	@echo "Confluent Platform for Flink Operator  -> should get 3 pods"
	@kubectl get pods -n confluent

create_ns:
	$(call ensure_ns, $(CFNT_NS))
	$(call ensure_ns, $(FLCK_NS))
# ------------ Postgresql ------------
deploy_postgresql_operator:
	@kubectl apply --server-side -f \
  https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.25/releases/cnpg-1.25.1.yaml

verify_postgresql_operator:
	@kubectl describe deployment -n cnpg-system cnpg-controller-manager

deploy_postgresql:
	@kubectl apply -f infrastructure/pg-cluster.yaml

deploy_pgadmin:
	@kubectl apply -f infrastructure/pg-admin.yaml
	@echo "pgadmin is available at http://localhost:30001"

