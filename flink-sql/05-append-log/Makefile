DB_NAME=j9r-kafka
ENV_NAME=env-nknqp3
MY_CONTEXT=login-jboyer@confluent.io-https://confluent.cloud
CPOOLID=lfcp-xvrvmz
CLOUD=aws
REGION=us-west-2

create_flink_statement = \
	sql_statement=$$(cat $2);\
	confluent flink statement create $1 --sql "$$sql_statement" --database $(DB_NAME) --compute-pool $(CPOOLID)  --environment $(ENV_NAME) --context $(MY_CONTEXT) --wait 

describe_flink_statement = \
	confluent flink statement describe $1 --cloud $(CLOUD) --region $(REGION) 

delete_flink_statement = \
	confluent flink statement delete $1 --cloud $(CLOUD) --region $(REGION) --context $(MY_CONTEXT)

drop_table = \
	sql_statement="drop table $2";\
	confluent flink statement create $1 --sql "$$sql_statement" --database $(DB_NAME) --compute-pool $(CPOOLID)   --environment $(ENV_NAME) --context $(MY_CONTEXT) --wait 

# ----------------------------------------------------------
# Orders
# ----------------------------------------------------------

deploy_orders_append_mode:
	$(call create_flink_statement, ddl-orders-append-mode, ./ddl.orders-append-mode.sql) 
	$(call delete_flink_statement, ddl-orders-append-mode) 

deploy_orders_retract_mode:
	$(call create_flink_statement, ddl-orders-retract-mode, ./ddl.orders-retract-mode.sql) 
	$(call delete_flink_statement, ddl-orders-retract-mode) 

deploy_orders_upsert_mode:
	$(call create_flink_statement, ddl-orders-upsert-mode, ./ddl.orders-upsert-mode.sql) 
	$(call delete_flink_statement, ddl-orders-upsert-mode) 

delete_orders_append_mode_statement:
	$(call delete_flink_statement, ddl-orders-append-mode) 

drop_orders:
	$(call drop_table, drop-orders, orders); \
	$(call delete_flink_statement, drop-orders) 

insert_orders:
	$(call create_flink_statement, dml-insert-orders, ./dml.insert-basic-orders.sql)
	$(call delete_flink_statement, dml-insert-orders) 

delete_orders_insert_statment:
	$(call delete_flink_statement, dml-insert-orders)

drop_enriched_orders:
	$(call drop_table, drop-orders, enriched_orders); \
	$(call delete_flink_statement, drop-orders) 

# ----------------------------------------------------------
# Products
# ----------------------------------------------------------
deploy_products:
	$(call create_flink_statement, ddl-products-append-mode, ./ddl.products-append-mode.sql) 
	$(call delete_flink_statement, ddl-products-append-mode) 

delete_products_ddl_statement:
	$(call delete_flink_statement, ddl-products-append-mode) 

delete_products_insert_statment:
	$(call delete_flink_statement, dml-insert-products)

insert_products:
	$(call create_flink_statement, dml-insert-products, ./dml.insert-products.sql)
	$(call delete_flink_statement, dml-insert-products) 

drop_products:
	$(call drop_table, drop_products, products); \
	$(call delete_flink_statement, drop_products) 