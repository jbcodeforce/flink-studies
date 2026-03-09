# -----------------------------------------------------------------------------
# Data Sources
# txp_dim_customers Flink Statements
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Remote State from IaC
# -----------------------------------------------------------------------------
# NOTE: The IaC infrastructure must be deployed first and the state file must exist.
# If you get an error about state not found, ensure:
# 1. The IaC has been applied: cd ../../IaC && terraform apply
# 2. The state file exists at the path specified in iac_state_path variable
# 3. The path is correct (default: ../../IaC/terraform.tfstate from this directory)
data "terraform_remote_state" "iac" {
  backend = "local"

  config = {
    path = abspath(var.iac_state_path)
  }
}

# -----------------------------------------------------------------------------
# Flink Region Data Source
# -----------------------------------------------------------------------------
data "confluent_flink_region" "flink_region" {
  cloud  = "AWS"
  region = var.cloud_region
}

# -----------------------------------------------------------------------------
# Organization Data Source
# -----------------------------------------------------------------------------
data "confluent_organization" "org" {}

# -----------------------------------------------------------------------------
# Environment Data Source
# Get environment display name for Flink properties
# -----------------------------------------------------------------------------
data "confluent_environment" "env" {
  id = data.terraform_remote_state.iac.outputs.confluent_environment_id
}

# -----------------------------------------------------------------------------
# Kafka Cluster Data Source
# Get cluster display name for Flink properties
# -----------------------------------------------------------------------------
data "confluent_kafka_cluster" "cluster" {
  id = data.terraform_remote_state.iac.outputs.kafka_cluster_id
  environment {
    id = data.terraform_remote_state.iac.outputs.confluent_environment_id
  }
}

# Note: The principal (service account) for Flink statements is inferred from
# the API key credentials. If you need to explicitly set it, add the service
# account ID to the IaC outputs and reference it here.
