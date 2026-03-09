# Those settings may need to be changed
ENV_NAME=${CCLOUD_ENV_NAME}
ENV_ID=${CCLOUD_ENV_ID}
CLOUD=${CLOUD_PROVIDER}
REGION=${CLOUD_REGION}
CC_CONTEXT=${CCLOUD_CONTEXT} 
DB_NAME=${CCLOUD_KAFKA_CLUSTER}
CPOOLID=${CCLOUD_COMPUTE_POOL_ID}


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
	sql_statement=$$(cat $2); \
	prop_file=$$(echo "$(3)" | sed 's/^[[:space:]]*//;s/[[:space:]]*$$//'); \
	if [ -n "$$prop_file" ] && [ -f "$$prop_file" ]; then \
		echo "Reading property file: $$prop_file"; \
		property_pairs=""; \
		while IFS= read -r line || [ -n "$$line" ]; do \
			line=$$(echo "$$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$$//'); \
			if [ -n "$$line" ] && ! echo "$$line" | grep -q "^\#" && echo "$$line" | grep -q "="; then \
				key=$$(echo "$$line" | cut -d'=' -f1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$$//'); \
				value=$$(echo "$$line" | cut -d'=' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$$//'); \
				if [ -n "$$key" ] && [ -n "$$value" ]; then \
					if [ -n "$$property_pairs" ]; then \
						property_pairs="$$property_pairs,$$key=$$value"; \
					else \
						property_pairs="$$key=$$value"; \
					fi; \
				fi; \
			fi; \
		done < "$$prop_file"; \
	fi; \
	if [ -n "$$property_pairs" ]; then \
		echo "Submitting statement with properties: $$property_pairs"; \
		confluent flink statement create $1 --sql "$$sql_statement" --property "$$property_pairs" --database $(DB_NAME) --compute-pool $(CPOOLID)  --environment $(ENV_ID) --context $(CC_CONTEXT) --wait; \
	else \
		confluent flink statement create $1 --sql "$$sql_statement" --database $(DB_NAME) --compute-pool $(CPOOLID)  --environment $(ENV_ID) --context $(CC_CONTEXT) --wait; \
	fi;

show_create_table = \
	sql_statement="show create table $2";\
	confluent flink statement create $1 --sql "$$sql_statement" --database $(DB_NAME) --compute-pool $(CPOOLID)   --environment $(ENV_ID) --context $(CC_CONTEXT) --wait 

drop_table = \
	sql_statement="drop table $2";\
	confluent flink statement create $1 --sql "$$sql_statement" --database $(DB_NAME) --compute-pool $(CPOOLID)   --environment $(ENV_ID) --context $(CC_CONTEXT) --wait 

describe_flink_statement = \
	confluent flink statement describe $1 --cloud $(CLOUD) --region $(REGION) 
	
pause_flink_statement = \
	confluent flink statement stop $1 --cloud $(CLOUD) --region $(REGION) 

resume_flink_statement = \
	confluent flink statement resume $1 --cloud $(CLOUD) --region $(REGION) 

delete_flink_statement = \
	confluent flink statement delete $1 --cloud $(CLOUD) --region $(REGION) --context $(CC_CONTEXT) --environment $(ENV_ID)

list_topic_content = \
	CLUSTER_ID=$$(confluent kafka cluster list --environment $$ENV_ID | awk -F '|' '{sub(/^[ \t]+/,"",$$2);sub(/[ \t]+$$/,"",$$2); print $$2}' | tail -1); \
	confluent kafka topic consume $1 --cluster $$CLUSTER_ID --environment $(ENV_ID) --from-beginning

# --- common
list_topics:
	CLUSTER_ID=$$(confluent kafka cluster list --environment $$ENV_ID | awk -F '|' '{sub(/^[ \t]+/,"",$$2);sub(/[ \t]+$$/,"",$$2); print $$2}' | tail -1);\
	confluent kafka topic list --cluster  $$CLUSTER_ID --environment $(ENV_ID)

# -- some useful targets
flink_list_statements:
	confluent flink statement list --context $(CC_CONTEXT) --output human --cloud $(CLOUD) --region $(REGION)   --compute-pool $$CPOOL_ID

start_flink_shell:
	confluent flink shell --compute-pool $(CPOOL_ID)  --context $(CC_CONTEXT) 

# -- init to get environments and compute pool
init: 
	export CLUSTER_ID=$$(confluent kafka cluster list --environment $(ENV_ID) | awk -F '|' '{sub(/^[ \t]+/,"",$$2);sub(/[ \t]+$$/,"",$$2); print $$2}' | tail -1); \
	echo $(ENV_ID) $$CLUSTER_ID $(CPOOLID);\
	confluent flink region use --cloud $(CLOUD) --region $(REGION);\
	confluent flink  endpoint use "https://flink.$(REGION).$(CLOUD).private.confluent.cloud"

