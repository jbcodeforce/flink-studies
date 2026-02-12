# DDL: customers table
resource "confluent_flink_statement" "ddl_customers" {
  organization {
    id = data.confluent_organization.org.id
  }
  environment {
    id = var.environment_id
  }
  compute_pool {
    id = var.flink_compute_pool_id
  }
  principal {
    id = var.principal_id
  }
  credentials {
    key    = var.flink_api_key
    secret = var.flink_api_secret
  }
  rest_endpoint   = var.flink_rest_endpoint
  statement       = file("${path.module}/../ddl.customers.sql")
  statement_name  = "${var.statement_name_prefix}-ddl-customers"
  properties      = local.flink_properties
}

# DML: insert into customers
resource "confluent_flink_statement" "insert_customers" {
  organization {
    id = data.confluent_organization.org.id
  }
  environment {
    id = var.environment_id
  }
  compute_pool {
    id = var.flink_compute_pool_id
  }
  principal {
    id = var.principal_id
  }
  credentials {
    key    = var.flink_api_key
    secret = var.flink_api_secret
  }
  rest_endpoint   = var.flink_rest_endpoint
  statement       = file("${path.module}/../insert_customers.sql")
  statement_name  = "${var.statement_name_prefix}-insert-customers"
  properties      = local.flink_properties
  depends_on      = [confluent_flink_statement.ddl_customers]
}

# DML: dedup_customers CTAS
resource "confluent_flink_statement" "dml_dedup_customers" {
  organization {
    id = data.confluent_organization.org.id
  }
  environment {
    id = var.environment_id
  }
  compute_pool {
    id = var.flink_compute_pool_id
  }
  principal {
    id = var.principal_id
  }
  credentials {
    key    = var.flink_api_key
    secret = var.flink_api_secret
  }
  rest_endpoint   = var.flink_rest_endpoint
  statement       = file("${path.module}/../dml.dedup_customers.sql")
  statement_name = "${var.statement_name_prefix}-dml-dedup-customers"
  properties      = local.flink_properties
  depends_on      = [confluent_flink_statement.ddl_customers]
}
