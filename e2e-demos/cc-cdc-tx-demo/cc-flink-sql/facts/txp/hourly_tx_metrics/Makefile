include ../../../common.mk

# --- txp_fct_hourly_tx_metrics
TABLE_NAME=txp_fct_daily_tx_metrics
SCRIPT_PRE_KEBAB=dev-usw2-txp
SCRIPT_POST_KEBAB=$(subst _,-,$(TABLE_NAME))

DDL_STATEMENT=$(SCRIPT_PRE_KEBAB)-ddl-$(SCRIPT_POST_KEBAB)
DROP_DDL_STATEMENT=$(SCRIPT_PRE_KEBAB)-drop-$(SCRIPT_POST_KEBAB)
DDL_SCRIPT=./sql-scripts/ddl.$(TABLE_NAME).sql
DML_STATEMENT=$(SCRIPT_PRE_KEBAB)-dml-$(SCRIPT_POST_KEBAB)
DML_SCRIPT=./sql-scripts/dml.$(TABLE_NAME).sql
DML_PROPERTIES=./sql-scripts/dml.$(TABLE_NAME).properties
DML_TESTS_SCRIPT=./tests/dml.$(TABLE_NAME).sql

# --- Entry point
create_txp_fct_daily_tx_metrics: create_flink_ddl  create_flink_dml


# --- Topic used as source
list_record_data_from_topic:
	$(call list_topic_content, $(TABLE_NAME))

# --- DDL 
create_flink_ddl: 
	$(call create_flink_statement, $(DDL_STATEMENT), $(DDL_SCRIPT)) 
	$(call delete_flink_statement, $(DDL_STATEMENT) )


describe_flink_ddl:
	$(call describe_flink_statement,  $(DDL_STATEMENT))

delete_flink_ddl:
	$(call delete_flink_statement, $(DDL_STATEMENT))

drop_table: 
	$(call drop_table, $(DROP_DDL_STATEMENT), $(TABLE_NAME))
	$(call delete_flink_statement, $(DROP_DDL_STATEMENT))

# --- DML
describe_flink_dml:
	$(call describe_flink_statement,  $(DML_STATEMENT))

create_flink_dml:
	$(call create_flink_statement, $(DML_STATEMENT), $(DML_SCRIPT), $(DML_PROPERTIES)) 

create_flink_dev:
	$(call create_flink_statement, $(DML_STATEMENT), $(DML_TESTS_SCRIPT)) 

delete_flink_dml:
	$(call delete_flink_statement, $(DML_STATEMENT))

pause_flink_dml:
	$(call pause_flink_statement $(DML_STATEMENT))

resume_flink_dml:
	$(call resume_flink_statement $(DML_STATEMENT))

delete_schemas:
	$(call delete_schema, $(TABLE_NAME)-value)
	$(call delete_schema, $(TABLE_NAME)-key)


delete_flink_statements: delete_flink_ddl delete_flink_dml

delete_data: delete_schemas