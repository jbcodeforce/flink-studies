
MINIO_NS=minio-dev

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
prepare: create_ns  deploy_minio verify_minio 

create_ns:
	$(call ensure_ns, $(MINIO_NS))

# ---------------------- Minio ----------------------
deploy_minio:
	@kubectl apply -f minio-dev.yaml 

port_forward_minio_console:
	@osascript -e 'tell app "Terminal" to do script "kubectl port-forward pod/minio 9090 9090 -n $(MINIO_NS)"'

verify_minio:
	@kubectl get pods -n $(MINIO_NS)
