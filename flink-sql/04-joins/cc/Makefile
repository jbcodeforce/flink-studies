include ../common.mk

# -- Compute the number of orders per customer per minute (non-overlapping window)
create_cc_customer_orders:
	$(call create_flink_statement, customer_orders, ./cc.customer_orders.sql) 

