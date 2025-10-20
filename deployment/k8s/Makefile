
MINIO_NS=minio-dev
CERT_MGR_VERSION=v1.18.1
FLINK_OPERATOR_VERSION=1.11.0
CMF_URL=http://localhost:8084
ENV_NAME=dev

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
	kubectl get ns

stop_colima:
	@colima stop

set_docker_context:
	@docker context use colima

# ------- Common elements to install -------------
prepare: create_ns  deploy_cert_manager verify_cert_manager deploy_minio verify_minio 

create_ns:
	$(call ensure_ns, $(MINIO_NS))

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
	@echo "----------------------------------------"



# ---------------------- Minio ----------------------
deploy_minio:
	@kubectl apply -f ./MinIO/minio-dev.yaml 

deploy_minio_secret:
	@kubectl apply -f minio-credentials-secret.yaml

port_forward_minio_console:
	@kubectl port-forward pod/minio 9000 9090 -n $(MINIO_NS)

verify_minio:
	@kubectl get pods -n $(MINIO_NS)
	@echo "----------------------------------------"


status: verify_minio verify_cert_manager
	@echo "----------------------------------------"
	cd cp-flink && make status
	@echo "----------------------------------------"
	cd cfk && make status
