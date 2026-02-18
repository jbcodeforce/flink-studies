# Confluent Cloud Environment and Environment Manager Service Account
# This is the base environment for j9r Flink applications

resource "confluent_environment" "env" {
  display_name = "${var.prefix}-env"

  stream_governance {
    package = "ESSENTIALS"
  }
}

# Reference existing env-manager service account (e.g. j9r-env-manager) by display name.
# To import into Terraform state instead, use: terraform import confluent_service_account.env-manager <sa-id>
data "confluent_service_account" "env-manager" {
  display_name = "${var.prefix}-env-manager"
}

resource "confluent_role_binding" "env-admin" {
  principal   = "User:${data.confluent_service_account.env-manager.id}"
  role_name   = "EnvironmentAdmin"
  crn_pattern = confluent_environment.env.resource_name
}
