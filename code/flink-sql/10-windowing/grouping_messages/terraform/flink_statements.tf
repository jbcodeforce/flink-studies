# 1. DDL: leads_raw table
resource "confluent_flink_statement" "ddl_lead_source" {
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
  statement       = file("${path.module}/../cc-flink/ddl.lead_source.sql")
  statement_name  = "${var.statement_name_prefix}-ddl-lead-source"
  properties      = local.flink_properties
}

# 2. DDL: bulk_leads table
resource "confluent_flink_statement" "ddl_bulk_leads" {
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
  statement       = file("${path.module}/../cc-flink/ddl.bulk_leads.sql")
  statement_name  = "${var.statement_name_prefix}-ddl-bulk-leads"
  properties      = local.flink_properties
}

# 3. Faker: leads_faker table
resource "confluent_flink_statement" "faker_lead" {
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
  statement       = file("${path.module}/../cc-flink/faker.lead.sql")
  statement_name  = "${var.statement_name_prefix}-faker-lead"
  properties      = local.flink_properties
}

# 4. DML: INSERT into leads_raw from leads_faker
resource "confluent_flink_statement" "dml_flatten_leads" {
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
  statement       = file("${path.module}/../cc-flink/dml.flatten_leads.sql")
  statement_name  = "${var.statement_name_prefix}-dml-flatten-leads"
  properties      = local.flink_properties
  depends_on      = [confluent_flink_statement.ddl_lead_source, confluent_flink_statement.faker_lead]
}

# 5. DML: INSERT into bulk_leads (window + LISTAGG from leads_raw)
resource "confluent_flink_statement" "dml_create_build_leads" {
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
  statement       = file("${path.module}/../cc-flink/dml.create_build_leads.sql")
  statement_name  = "${var.statement_name_prefix}-dml-create-build-leads"
  properties      = local.flink_properties
  depends_on      = [confluent_flink_statement.ddl_lead_source, confluent_flink_statement.ddl_bulk_leads]
}
