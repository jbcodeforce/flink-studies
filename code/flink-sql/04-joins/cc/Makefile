include ../../common.mk

# -- Compute the number of orders per customer per minute (non-overlapping window)
create_cc_customer_orders:
	$(call create_flink_statement, customer_orders, ./cc.customer_orders.sql) 

create_cc_orders:
	$(call create_flink_statement, ddl.orders, ./cc_s2s_ddl_orders.sql) 

create_cc_products:
	$(call create_flink_statement, ddl.orders, ./cc_s2s_ddl_products.sql) 

create_cc_shipments:
	$(call create_flink_statement, ddl.orders, ./cc_s2s_ddl_shipments.sql) 
