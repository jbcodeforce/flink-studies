# Those settings may need to be changed
ENV_NAME=prod
CLOUD=aws
REGION=us-east-1
MY_CONTEXT= login-jboyer@confluent.io-https://confluent.cloud 
#DB_NAME=lkc-663njj
DB_NAME=marketplace

	

# --- common functions
delete_schema = \
	@echo "Attempting to delete schema for subject: $1"; \
	V=$$(confluent schema-registry subject describe $1 2>/dev/null | grep -o '[0-9]*' | head -n 1);\
	echo $$V; \
	if [ -n "$$V" ]; \
	then \
		echo "$1  found"; \
		confluent schema-registry schema delete --subject $1 --version $$V --force; \
		confluent schema-registry schema delete --subject $1 --version $$V --permanent --force; \
	else \
		echo "$1 not found"; \
	fi

create_flink_statement = \
	ENV_ID=$$(confluent environment list | grep ${ENV_NAME} | awk -F '|' '{sub(/^[ \t]+/,"",$$2);sub(/[ \t]+$$/,"",$$2); print $$2}'); \
	sql_statement=$$(cat $2);\
	CPOOL_ID=$$(confluent flink compute-pool list | awk -F '|' '{sub(/^[ \t]+/,"",$$2);sub(/[ \t]+$$/,"",$$2); print $$2}' | tail -1);\
	echo $$CPOOL_ID;\
	confluent flink statement create $1 --sql "$$sql_statement" --database $(DB_NAME) --compute-pool $$CPOOL_ID  --environment $$ENV_ID --context $(MY_CONTEXT) --wait 

pause_flink_statement = \
	CPOOL_ID=$$(confluent flink compute-pool list | awk -F '|' '{sub(/^[ \t]+/,"",$$2);sub(/[ \t]+$$/,"",$$2); print $$2}' | tail -1);\
	echo $$CPOOL_ID;\
	confluent flink statement stop $1 --cloud $(CLOUD) --region $(REGION) 

resume_flink_statement = \
	CPOOL_ID=$$(confluent flink compute-pool list | awk -F '|' '{sub(/^[ \t]+/,"",$$2);sub(/[ \t]+$$/,"",$$2); print $$2}' | tail -1);\
	echo $$CPOOL_ID;\
	confluent flink statement resume $1 --cloud $(CLOUD) --region $(REGION) 

delete_flink_statement = \
	confluent flink statement delete $1 --cloud $(CLOUD) --region $(REGION) --context $(MY_CONTEXT)

list_topic_content = \
	ENV_ID=$$(confluent environment list | grep ${ENV_NAME} | awk -F '|' '{sub(/^[ \t]+/,"",$$2);sub(/[ \t]+$$/,"",$$2); print $$2}'); \
	CLUSTER_ID=$$(confluent kafka cluster list --environment $$ENV_ID | awk -F '|' '{sub(/^[ \t]+/,"",$$2);sub(/[ \t]+$$/,"",$$2); print $$2}' | tail -1); \
	confluent kafka topic consume $1 --cluster $$CLUSTER_ID --environment $$ENV_ID --from-beginning

# --- common
list_topics: 
	ENV_ID=$$(confluent environment list | grep ${ENV_NAME} | awk -F '|' '{sub(/^[ \t]+/,"",$$2);sub(/[ \t]+$$/,"",$$2); print $$2}'); \
	CLUSTER_ID=$$(confluent kafka cluster list --environment $$ENV_ID | awk -F '|' '{sub(/^[ \t]+/,"",$$2);sub(/[ \t]+$$/,"",$$2); print $$2}' | tail -1); \
	confluent kafka topic list --cluster  $$CLUSTER_ID --environment $$ENV_ID
	
# -- some useful targets
flink_list_statements:
	export CPOOL_ID=$$(confluent flink compute-pool list | awk -F '|' '{sub(/^[ \t]+/,"",$$2);sub(/[ \t]+$$/,"",$$2); print $$2}' | tail -1); \
	confluent flink statement list --context $(MY_CONTEXT) --output human --cloud $(CLOUD) --region $(REGION)   --compute-pool $$CPOOL_ID

start_flink_shell:
	export CPOOL_ID=$$(confluent flink compute-pool list | awk -F '|' '{sub(/^[ \t]+/,"",$$2);sub(/[ \t]+$$/,"",$$2); print $$2}' | tail -1); \
	confluent flink shell --compute-pool $$CPOOL_ID  --context $(MY_CONTEXT) 

# -- init to get environments and compute pool
init: 
	@echo "Set env variables from $(ENV_NAME)"; \
	export ENV_ID=$$(confluent environment list | grep ${ENV_NAME} | awk -F '|' '{sub(/^[ \t]+/,"",$$2);sub(/[ \t]+$$/,"",$$2); print $$2}'); \
	export CLUSTER_ID=$$(confluent kafka cluster list --environment $$ENV_ID | awk -F '|' '{sub(/^[ \t]+/,"",$$2);sub(/[ \t]+$$/,"",$$2); print $$2}' | tail -1); \
	export CPOOL_ID=$$(confluent flink compute-pool list | awk -F '|' '{sub(/^[ \t]+/,"",$$2);sub(/[ \t]+$$/,"",$$2); print $$2}' | tail -1); \
	echo $$ENV_ID $$CLUSTER_ID $$CPOOL_ID