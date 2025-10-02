CFNT_NS=confluent
FLCK_NS=flink
DEMO_NS=el-demo
CERT_MGR_VERSION=v1.18.1
FLINK_OPERATOR_VERSION=1.11.0
CMF_URL=http://localhost:8084
ENV_NAME=env1
APP_NAME=external-lookup


# ---------------------- Common functions ----------------------
ensure_ns = \
	@kubectl get ns $1 >/dev/null 2>&1; \
	if [ $$? -ne 0 ]; then \
			kubectl create ns $1; \
	else \
			echo "namespace: $1 exists";\
	fi


# ---------------------- Colima ----------------------
start_colima:
	@colima start --cpu 8 --memory 24 --kubernetes

stop_colima:
	@colima stop

set_docker_context:
	@docker context use colima

# ------- Common elements to install -------------
prepare: set_docker_context create_ns 

create_ns:
	$(call ensure_ns, $(DEMO_NS))

use_demo_ns:
	@kubectl config set-context --current --namespace=$(DEMO_NS)

use_flink_ns:
	@kubectl config set-context --current --namespace=$(FLCK_NS)

use_cp_ns:
	@kubectl config set-context --current --namespace=$(CFNT_NS)

# ---------------------- Confluent Platform ----------------------
port_forward_cp_console:
	@osascript -e 'tell app "Terminal" to do script "kubectl -n $(CFNT_NS) port-forward svc/controlcenter-ng 9021:9021"' -e 'tell application "Terminal" to set current settings of front window to settings set "Pro"'


port_forward_kafka_bootstrap_old:
	@osascript -e 'tell app "Terminal" to do script "kubectl -n $(CFNT_NS) port-forward svc/kafka 9092:9092"'

# ---------------------- Confluent Manager for Flink ----------------------

port_forward_cmf:
	@osascript -e 'tell app "Terminal" to do script "kubectl port-forward svc/cmf-service 8084:80 -n $(FLCK_NS)"'

list_flink_env:
	@confluent flink environment list --url $(CMF_URL)

create_compute_pool:
	@confluent flink compute-pool create ../cmf/compute_pool.json --environment $(ENV_NAME) --url $(CMF_URL)

list_compute_pools:
	@confluent flink compute-pool list --environment $(ENV_NAME) --url $(CMF_URL)



# ----------- Applications ----------------------

create_topics:
	@kubectl apply -f k8s/enriched-payments-topic.yaml
	@kubectl apply -f k8s/failed-payments-topic.yaml
	@kubectl apply -f k8s/payment-events-topic.yaml

port_forward_claimdb_api:
	@echo "Getting ClaimDB pod name and starting port-forward..."
	@POD_NAME=$$(kubectl get pods -n $(DEMO_NS) -l app=$(APP_NAME) -o jsonpath='{.items[0].metadata.name}' 2>/dev/null); \
	if [ -n "$$POD_NAME" ]; then \
		echo "Port-forwarding to pod: $$POD_NAME"; \
		osascript -e "tell app \"Terminal\" to do script \"kubectl -n $(DEMO_NS) port-forward pod/$$POD_NAME 8080:8080\"" -e 'tell application "Terminal" to set current settings of front window to settings set "Ocean"'; \
	else \
		echo "❌ No ClaimDB pods found in namespace $(DEMO_NS)"; \
		echo "Available pods:"; \
		kubectl get pods -n $(DEMO_NS); \
	fi

port_forward_event_generator_metrics:
	@osascript -e 'tell app "Terminal" to do script "kubectl -n $(DEMO_NS) port-forward svc/event-generator-metrics 8090:8090"' -e 'tell application "Terminal" to set current settings of front window to settings set "Grass"'

port_forward_kafka_bootstrap:
	@echo "🔗 Starting Kafka port-forward..."
	@POD_NAME=$$(kubectl get pods -n $(CFNT_NS) -l app=kafka -o jsonpath='{.items[0].metadata.name}' 2>/dev/null); \
	if [ -n "$$POD_NAME" ]; then \
		echo "Port-forwarding to pod: $$POD_NAME"; \
		echo "✅ Kafka port-forward started on localhost:9092"; \
		osascript -e "tell app \"Terminal\" to do script \"kubectl -n $(CFNT_NS) port-forward pod/$$POD_NAME 9092:9092\"" -e 'tell application "Terminal" to set current settings of front window to settings set "Ocean"'; \
	else \
		echo "❌ No kafka pods found in namespace $(CFNT_NS)"; \
		echo "Available pods:"; \
		kubectl get pods -n $(CFNT_NS); \
	fi


expose_services:
	make port_forward_cp_console
	make port_forward_cmf
	make port_forward_kafka_bootstrap
	make port_forward_event_generator_metrics

# ----------- Kafka Consumer Tools ----------------------

install_consumer_deps: ## Install Python dependencies for Kafka consumer
	@echo "📦 Installing Kafka consumer dependencies..."
	@uv add kafka-python
	@echo "✅ Dependencies installed"


# Access directly in cluster (when consumer runs in k8s)
consume_payment_events_cluster: ## Consume from payment-events topic (direct cluster access)
	@echo "🎧 Consuming from payment-events topic via cluster service..."
	@kubectl -n el-demo exec kafka-consumer-interactive -- python /scripts/kafka_consumer.py -t payment-events -b kafka.confluent.svc.cluster.local:9071 --from-beginning --max-messages 5

consume_enriched_payments_cluster: ## Consume from enriched-payments topic (direct cluster access)
	@echo "🎧 Consuming from enriched-payments topic via cluster service..."
	@kubectl -n el-demo exec kafka-consumer-interactive -- python /scripts/kafka_consumer.py -t enriched-payments -b kafka.confluent.svc.cluster.local:9071--from-beginning --max-messages 5

consume_failed_payments_cluster: ## Consume from failed-payments topic (direct cluster access)
	@echo "🎧 Consuming from failed-payments topic via cluster service..."
	@kubectl -n el-demo exec kafka-consumer-interactive -- python /scripts/kafka_consumer.py -t failed-payments -b kafka.confluent.svc.cluster.local:9071 --from-beginning --max-messages 5


# Kubernetes-based consumer
deploy_kafka_consumer_k8s: ## Deploy Kafka consumer tools to Kubernetes
	@echo "🚀 Deploying Kafka consumer tools to Kubernetes..."
	@kubectl apply -f tools/kafka-consumer-k8s.yaml
	@echo "✅ Kafka consumer tools deployed"
	@echo "💡 Use: make exec_kafka_consumer_k8s"

exec_kafka_consumer_k8s: ## Execute commands in Kafka consumer pod
	@echo "🎧 Executing interactive session in Kafka consumer pod..."
	@kubectl exec -it kafka-consumer-interactive -n $(DEMO_NS) -- /bin/bash

logs_kafka_consumer_job: ## Show logs from Kafka consumer job
	@echo "📋 Kafka consumer job logs:"
	@kubectl logs job/kafka-consumer-payment-events -n $(DEMO_NS)

clean_kafka_consumer_k8s: ## Remove Kafka consumer tools from Kubernetes
	@echo "🗑️ Removing Kafka consumer tools..."
	@kubectl delete -f tools/kafka-consumer-k8s.yaml --ignore-not-found
	@echo "✅ Kafka consumer tools removed"

consumer_help: ## Show Kafka consumer usage examples
	@echo "📋 Kafka Consumer Usage Examples:"
	@echo "=================================="
	@echo ""
	@echo "🔗 Kafka Access Methods:"
	@echo "========================"
	@echo "1️⃣   Direct Cluster Access (Internal):"
	@echo "   - Broker: kafka.confluent.svc.cluster.local:9092"
	@echo "   - Use: make consume_payment_events_cluster"
	@echo ""
	@echo "2️⃣   Kubernetes Pod Consumer:"
	@echo "   - Deploy: make deploy_kafka_consumer_k8s"
	@echo "   - Exec: make exec_kafka_consumer_k8s"
	@echo ""
	@echo "🚀 Quick Start:"
	@echo "  make install_consumer_deps     # Install Python dependencies"
	@echo "  make deploy_kafka_consumer_k8s     # Deploy consumer pod"
	@echo ""
	@echo "🌐 Consumer Commands (Cluster Access):"
	@echo "  make consume_payment_events_cluster    # Direct cluster access"
	@echo "  make consume_enriched_payments_cluster # Direct cluster access"
	@echo "  make consume_failed_payments_cluster   # Direct cluster access"
	@echo ""
	@echo ""
	@echo "☸️  Kubernetes Consumer:"
	@echo "  make exec_kafka_consumer_k8s       # Interactive shell"
	@echo "  make logs_kafka_consumer_job       # View job logs"
	@echo "  make clean_kafka_consumer_k8s      # Remove pod"
	@echo ""
	