CFNT_NS=confluent
FLCK_NS=flink
CMF_URL=http://localhost:8084

# Other services port forwarding
port-forward-minio-console:
	@osascript -e 'tell app "Terminal" to do script "kubectl port-forward pod/minio 9090 9090 -n $(MINIO_NS)"' -e 'tell application "Terminal" to set custom title of selected tab of the front window to "Minio Console"'


# ---------------------- Confluent Kafka ----------------------
use_cp_ns:
	@kubectl config set-context --current --namespace=$(CFNT_NS)

port_forward_cp_console:
	@osascript -e 'tell app "Terminal" to do script "kubectl -n $(CFNT_NS) port-forward svc/controlcenter-ng 9021:9021"'

port_forward_schema_registry:
	@osascript -e 'tell app "Terminal" to do script "kubectl -n $(CFNT_NS) port-forward svc/schemaregistry 8081:8081"'

port_forward_kafka_bootstrap:
	@osascript -e 'tell app "Terminal" to do script "kubectl -n $(CFNT_NS) port-forward svc/kafka 9092:9092"'


# ---------------------- Flink ----------------------
use_flink_ns:
	@kubectl config set-context --current --namespace=$(FLCK_NS)

list_compute_pools:
	@confluent flink compute-pool list --environment env1 --url $(CMF_URL)

port_forward_cmf:
	@osascript -e 'tell app "Terminal" to do script "kubectl port-forward svc/cmf-service 8084:80 -n $(FLCK_NS)"'

start_flink_shell:
	@osascript -e 'tell app "Terminal" to do script "confluent flink shell --environment env1 --compute-pool pool1 --url $(CMF_URL);"' -e 'tell application "Terminal" to set current settings of window 1 to settings set "Ocean"'

# --- demo setup ---

create_raw_order: create_raw_orders_cm create_raw_orders_topic create_raw_orders_schema

delete_raw_order: delete_raw_orders_topic delete_raw_orders_schema delete_raw_orders_cm 

create_raw_job: create_raw_jobs_cm create_raw_jobs_topic create_raw_jobs_schema

delete_raw_job:  delete_raw_jobs_topic delete_raw_jobs_schema delete_raw_jobs_cm

create_order_details: create_order_details_cm create_order_details_topic create_order_details_schema

delete_order_details: delete_order_details_topic delete_order_details_schema delete_order_details_cm 

create_app_kafka_elements: create_raw_order create_raw_job create_order_details

delete_app_kafka_elements: delete_raw_order delete_raw_job delete_order_details

# ----- orders -----
create_raw_orders_cm:
	@echo "Creating raw-orders ConfigMap from schema file..."
	@kubectl create configmap raw-orders-value \
		--from-file=schema=schemas/raw-orders-schema.json \
		-n $(CFNT_NS) \
		--dry-run=client -o yaml | kubectl apply -f -

create_raw_orders_topic:
	@kubectl apply -f raw_orders_topic.yaml -n $(CFNT_NS)

create_raw_orders_schema:
	@kubectl apply -f raw_orders_schema.yaml -n $(CFNT_NS)

delete_raw_orders_cm:
	@kubectl delete -f raw_orders_cm.yaml -n $(CFNT_NS)

delete_raw_orders_topic:
	@kubectl delete -f raw_orders_topic.yaml -n $(CFNT_NS)

delete_raw_orders_schema:
	@kubectl delete -f raw_orders_schema.yaml -n $(CFNT_NS)

create_order_details_cm:
	@kubectl apply -f order_details_cm.yaml -n $(CFNT_NS)

delete_order_details_cm:
	@kubectl delete -f order_details_cm.yaml -n $(CFNT_NS)

create_order_details_schema:
	@kubectl apply -f order_details_schema.yaml -n $(CFNT_NS)

delete_order_details_schema:
	@kubectl delete -f order_details_schema.yaml -n $(CFNT_NS)

create_order_details_topic:
	@kubectl apply -f order_details_topic.yaml -n $(CFNT_NS)

delete_order_details_topic:
	@kubectl delete -f order_details_topic.yaml -n $(CFNT_NS)

# ----- jobs -----
create_raw_jobs_cm:
	@kubectl apply -f raw_jobs_cm.yaml -n $(CFNT_NS)

delete_raw_jobs_cm:
	@kubectl delete -f raw_jobs_cm.yaml -n $(CFNT_NS)

delete_raw_jobs_topic:
	@kubectl delete -f raw_jobs_topic.yaml -n $(CFNT_NS)

delete_raw_jobs_schema:
	@kubectl delete -f raw_jobs_schema.yaml -n $(CFNT_NS)

create_raw_jobs_topic:
	@kubectl apply -f raw_jobs_topic.yaml -n $(CFNT_NS)


create_topics: create_raw_orders_topic create_raw_jobs_topic

create_kafka_client_cm:
	@kubectl apply -f kafka_client_cm.yaml -n $(CFNT_NS)

create_cms: create_raw_jobs_cm create_raw_orders_cm create_kafka_client_cm create_order_details_cm

create_raw_jobs_schema:
	@kubectl apply -f raw_jobs_schema.yaml -n $(CFNT_NS)

create_schemas: create_raw_jobs_schema create_raw_orders_schema

deploy_order_producer:
	@kubectl apply -f orders_producer_pod.yaml -n $(CFNT_NS)

delete_order_producer:
	@kubectl delete -f orders_producer_pod.yaml -n $(CFNT_NS)

deploy_job_producer:
	@kubectl apply -f jobs_producer_pod.yaml -n $(CFNT_NS)

delete_job_producer:
	@kubectl delete -f jobs_producer_pod.yaml -n $(CFNT_NS)

# ---------------------- Producer API ----------------------

deploy_producer_api:
	@kubectl apply -f producer_api_pod.yaml -n $(CFNT_NS)

delete_producer_api:
	@kubectl delete -f producer_api_pod.yaml -n $(CFNT_NS)

port_forward_producer_api:
	@osascript -e 'tell app "Terminal" to do script "kubectl -n $(CFNT_NS) port-forward svc/producer-api-service 8080:80"'

# Deploy all producers (CLI + API)
deploy_all_producers: deploy_order_producer deploy_job_producer deploy_producer_api

# Delete all producers
delete_all_producers: delete_order_producer delete_job_producer delete_producer_api

# Check producer pods status
status_producers:
	@echo "=== Producer Pods Status ==="
	@kubectl get pods -n $(CFNT_NS) -l component=producer -o wide
	@echo "\n=== Producer API Services ==="
	@kubectl get svc -n $(CFNT_NS) -l app=producer-api -o wide
	@echo "\n🌐 Direct access: http://localhost:30080"
	@echo "🔗 Port-forward access: http://localhost:8080 (requires 'make port_forward_producer_api')"

# View producer logs
logs_order_producer:
	@kubectl logs -n $(CFNT_NS) orders-producer -f

logs_job_producer:
	@kubectl logs -n $(CFNT_NS) jobs-producer -f

logs_producer_api:
	@kubectl logs -n $(CFNT_NS) producer-api -f

# Test API endpoints via NodePort (direct access)
test_api_health_nodeport:
	@curl -s http://localhost:30080/health | jq .

test_api_produce_orders_nodeport:
	@curl -X POST http://localhost:30080/produce \
	  -H "Content-Type: application/json" \
	  -d '{"type": "order", "topic": "raw-orders", "count": 3}' | jq .

test_api_produce_jobs_nodeport:
	@curl -X POST http://localhost:30080/produce \
	  -H "Content-Type: application/json" \
	  -d '{"type": "job", "topic": "raw-jobs", "count": 2}' | jq .

test_api_list_jobs_nodeport:
	@curl -s http://localhost:30080/jobs | jq .

# Test API endpoints via Port Forward (requires port-forward to be running)
test_api_health:
	@curl -s http://localhost:8080/health | jq .

test_api_produce_orders:
	@curl -X POST http://localhost:8080/produce \
	  -H "Content-Type: application/json" \
	  -d '{"type": "order", "topic": "raw-orders", "count": 3}' | jq .

test_api_produce_jobs:
	@curl -X POST http://localhost:8080/produce \
	  -H "Content-Type: application/json" \
	  -d '{"type": "job", "topic": "raw-jobs", "count": 2}' | jq .

test_api_list_jobs:
	@curl -s http://localhost:8080/jobs | jq .


	