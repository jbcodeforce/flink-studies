


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
	@echo "Confluent Platform for Flink Operator  -> should get 7 pods"
	@kubectl get pods -n confluent

# ------------ Postgresql ------------
deploy_postgresql_operator:
	@kubectl apply --server-side -f \
  https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.27/releases/cnpg-1.27.1.yaml

verify_postgresql_operator:
	@kubectl describe deployment -n cnpg-system cnpg-controller-manager

deploy_postgresql:
	@kubectl apply -f infrastructure/pg-cluster.yaml

verify_postgresql:
	@kubectl get cluster -n pgdb
	@kubectl get pods -n pgdb
	@kubectl get svc -n pgdb

deploy_pgadmin:
	@kubectl apply -f infrastructure/pg-admin.yaml
	@echo "pgadmin is available at http://localhost:30001"

port_forward_pg: ## Port forward the MinIO console
	echo "Opening new terminal for port-forwarding..."; \
	osascript -e "tell application \"Terminal\" to do script \"echo 'Port-forwarding Postgresql from pod pg-cluster-1'; kubectl port-forward pg-cluster-1 5432 5432 -n pgdb; echo 'Port-forwarding stopped. You can close this terminal.'; read -p 'Press Enter to close...'\""