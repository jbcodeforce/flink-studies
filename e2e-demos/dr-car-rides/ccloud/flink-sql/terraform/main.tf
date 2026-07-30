# -----------------------------------------------------------------------------
# Phase 2 Terraform — primary Flink statements + Tableflow
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.3.0"
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "~> 2.58"
    }
  }
}

provider "confluent" {
  cloud_api_key    = var.confluent_cloud_api_key
  cloud_api_secret = var.confluent_cloud_api_secret
}

variable "confluent_cloud_api_key" {
  type      = string
  default   = ""
  sensitive = true
}

variable "confluent_cloud_api_secret" {
  type      = string
  default   = ""
  sensitive = true
}

variable "iac_state_path" {
  description = "Path to Phase 1 terraform.tfstate"
  type        = string
  default     = "../../IaC/terraform.tfstate"
}

variable "statement_name_prefix" {
  type    = string
  default = "dr-rides-primary"
}

variable "deploy_site" {
  description = "primary or dr — selects cluster/pool/bucket from IaC outputs"
  type        = string
  default     = "primary"
  validation {
    condition     = contains(["primary", "dr"], var.deploy_site)
    error_message = "deploy_site must be primary or dr"
  }
}

data "terraform_remote_state" "iac" {
  backend = "local"
  config = {
    path = abspath(var.iac_state_path)
  }
}

data "confluent_organization" "org" {}

locals {
  is_primary = var.deploy_site == "primary"
  environment_id = local.is_primary ? data.terraform_remote_state.iac.outputs.primary_environment_id : data.terraform_remote_state.iac.outputs.dr_environment_id
  environment_display_name = local.is_primary ? data.terraform_remote_state.iac.outputs.primary_environment_display_name : data.terraform_remote_state.iac.outputs.dr_environment_display_name
  kafka_cluster_id = local.is_primary ? data.terraform_remote_state.iac.outputs.primary_kafka_cluster_id : data.terraform_remote_state.iac.outputs.dr_kafka_cluster_id
  kafka_cluster_display_name = local.is_primary ? data.terraform_remote_state.iac.outputs.primary_kafka_cluster_display_name : data.terraform_remote_state.iac.outputs.dr_kafka_cluster_display_name
  flink_pool_id = local.is_primary ? data.terraform_remote_state.iac.outputs.primary_flink_compute_pool_id : data.terraform_remote_state.iac.outputs.dr_flink_compute_pool_id
  flink_rest_endpoint = local.is_primary ? data.terraform_remote_state.iac.outputs.primary_flink_rest_endpoint : data.terraform_remote_state.iac.outputs.dr_flink_rest_endpoint
  flink_api_key = local.is_primary ? data.terraform_remote_state.iac.outputs.flink_api_key_primary : data.terraform_remote_state.iac.outputs.flink_api_key_dr
  flink_api_secret = local.is_primary ? data.terraform_remote_state.iac.outputs.flink_api_secret_primary : data.terraform_remote_state.iac.outputs.flink_api_secret_dr
  s3_bucket = local.is_primary ? data.terraform_remote_state.iac.outputs.primary_s3_bucket_name : data.terraform_remote_state.iac.outputs.dr_s3_bucket_name
  cloud_region = local.is_primary ? data.terraform_remote_state.iac.outputs.primary_region : data.terraform_remote_state.iac.outputs.dr_region
  tableflow_provider_integration_id = local.is_primary ? try(data.terraform_remote_state.iac.outputs.tableflow_provider_integration_id_primary, "") : try(data.terraform_remote_state.iac.outputs.tableflow_provider_integration_id_dr, "")

  base_properties = {
    "sql.current-catalog"  = local.environment_display_name
    "sql.current-database" = local.kafka_cluster_display_name
  }

  tables = {
    rides_raw = {
      ddl_path        = "../sql-scripts/ddl.rides_raw.sql"
      dml_path        = null
      properties_path = null
      has_dml         = false
    }
    rides_clean = {
      ddl_path        = "../sql-scripts/ddl.rides_clean.sql"
      dml_path        = "../sql-scripts/dml.rides_clean.sql"
      properties_path = "../sql-scripts/dml.rides_clean.properties"
      has_dml         = true
    }
    driver_stats = {
      ddl_path        = "../sql-scripts/ddl.driver_stats.sql"
      dml_path        = "../sql-scripts/dml.driver_stats.sql"
      properties_path = "../sql-scripts/dml.driver_stats.properties"
      has_dml         = true
    }
  }

  parse_properties = {
    for name, cfg in local.tables : name => (
      cfg.properties_path != null ? merge(
        local.base_properties,
        {
          for line in [
            for l in split("\n", try(file(cfg.properties_path), "")) :
            trimspace(l)
            if length(trimspace(l)) > 0 && !startswith(trimspace(l), "#")
          ] :
          split("=", line)[0] => try(split("=", line)[1], "")
          if length(split("=", line)) == 2
        }
      ) : local.base_properties
    )
  }
}

data "confluent_flink_region" "site" {
  cloud  = "AWS"
  region = local.cloud_region
}

resource "confluent_flink_statement" "ddl" {
  for_each = local.tables

  organization {
    id = data.confluent_organization.org.id
  }
  environment {
    id = local.environment_id
  }
  compute_pool {
    id = local.flink_pool_id
  }
  principal {
    id = data.terraform_remote_state.iac.outputs.flink_service_account_id
  }

  rest_endpoint = data.confluent_flink_region.site.rest_endpoint
  credentials {
    key    = local.flink_api_key
    secret = local.flink_api_secret
  }

  statement      = file(each.value.ddl_path)
  statement_name = "${var.statement_name_prefix}-ddl-${replace(each.key, "_", "-")}"
  properties     = local.base_properties
}

resource "confluent_flink_statement" "dml" {
  for_each = {
    for name, cfg in local.tables : name => cfg
    if cfg.has_dml && cfg.dml_path != null
  }

  organization {
    id = data.confluent_organization.org.id
  }
  environment {
    id = local.environment_id
  }
  compute_pool {
    id = local.flink_pool_id
  }
  principal {
    id = data.terraform_remote_state.iac.outputs.flink_service_account_id
  }

  rest_endpoint = data.confluent_flink_region.site.rest_endpoint
  credentials {
    key    = local.flink_api_key
    secret = local.flink_api_secret
  }

  statement      = file(each.value.dml_path)
  statement_name = "${var.statement_name_prefix}-dml-${replace(each.key, "_", "-")}"
  properties     = local.parse_properties[each.key]

  depends_on = [confluent_flink_statement.ddl]
}

resource "confluent_tableflow_topic" "driver_stats" {
  count = local.tableflow_provider_integration_id != "" ? 1 : 0

  environment {
    id = local.environment_id
  }
  kafka_cluster {
    id = local.kafka_cluster_id
  }

  display_name  = "driver_stats"
  table_formats = ["ICEBERG"]

  byob_aws {
    bucket_name             = local.s3_bucket
    provider_integration_id = local.tableflow_provider_integration_id
  }

  credentials {
    key    = data.terraform_remote_state.iac.outputs.tableflow_api_key
    secret = data.terraform_remote_state.iac.outputs.tableflow_api_secret
  }

  depends_on = [
    confluent_flink_statement.ddl["driver_stats"],
    confluent_flink_statement.dml["driver_stats"],
  ]
}

output "deploy_site" {
  value = var.deploy_site
}

output "flink_statement_names" {
  value = concat(
    [for k, v in confluent_flink_statement.ddl : v.statement_name],
    [for k, v in confluent_flink_statement.dml : v.statement_name],
  )
}
