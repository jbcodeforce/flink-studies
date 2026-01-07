# Confluent Cloud Environment and Environment Manager Service Account
# This is the base environment for j9r Flink applications

resource "confluent_environment" "env" {
  display_name = "${var.prefix}-env"

  stream_governance {
    package = "ADVANCED"
  }
}

resource "confluent_service_account" "env-manager" {
  display_name = "${var.prefix}-env-manager"
  description  = "Service account to manage ${var.prefix} environment"
  depends_on = [
    confluent_environment.env
  ]
}

resource "confluent_role_binding" "env-admin" {
  principal   = "User:${confluent_service_account.env-manager.id}"
  role_name   = "EnvironmentAdmin"
  crn_pattern = confluent_environment.env.resource_name
}
