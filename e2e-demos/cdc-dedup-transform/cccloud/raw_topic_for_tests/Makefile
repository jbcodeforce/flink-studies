include ../common.mk

# --- 
TABLE_NAME=qlik_cdc_output_table
SCRIPT_PRE_KEBAB=dev
SCRIPT_POST_KEBAB=$(subst _,-,$(TABLE_NAME))

DDL_STATEMENT=$(SCRIPT_PRE_KEBAB)-ddl-$(SCRIPT_POST_KEBAB)
DROP_DDL_STATEMENT=$(SCRIPT_PRE_KEBAB)-drop-$(SCRIPT_POST_KEBAB)
DDL_SCRIPT=ddl.cdc_raw_table.sql
DML_STATEMENT=$(SCRIPT_PRE_KEBAB)-dml-$(SCRIPT_POST_KEBAB)
DML_SCRIPT=insert_raw_test_data.sql


# --- Topic used as source
list_record_data_from_topic:
	$(call list_topic_content, $(TABLE_NAME))

# --- DDL 
create_raw_table: 
	$(call create_flink_statement, $(DDL_STATEMENT), $(DDL_SCRIPT)) 
	$(call delete_flink_statement, $(DDL_STATEMENT) )


describe_raw_table:
	$(call describe_flink_statement,  $(DDL_STATEMENT))

delete_raw_table:
	$(call delete_flink_statement, $(DDL_STATEMENT))

drop_table: 
	$(call drop_table, $(DROP_DDL_STATEMENT), $(TABLE_NAME))
	$(call delete_flink_statement, $(DROP_DDL_STATEMENT))

# --- DML
describe_raw_data:
	$(call describe_flink_statement,  $(DML_STATEMENT))

insert_raw_data:
	$(call create_flink_statement, $(DML_STATEMENT), $(DML_SCRIPT)) 

delete_raw_data:
	$(call delete_flink_statement, $(DML_STATEMENT))

pause_raw_data:
	$(call pause_flink_statement $(DML_STATEMENT))

resume_raw_data:
	$(call resume_flink_statement $(DML_STATEMENT))
