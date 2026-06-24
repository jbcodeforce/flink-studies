# Schema Registry RBAC for CREATE TABLE with avro-registry (table management layer).
# See https://docs.confluent.io/cloud/current/flink/operate-and-deploy/flink-rbac.html

data "confluent_schema_registry_cluster" "essentials" {
  count = local.kafka_rbac_enabled ? 1 : 0

  environment {
    id = local.env_id
  }

  depends_on = [confluent_kafka_cluster.kafka]
}

locals {
  sr_rbac_base = local.kafka_rbac_enabled ? (
    "${data.confluent_schema_registry_cluster.essentials[0].resource_name}/subject=${var.schema_registry_subject_pattern}"
  ) : ""
}

resource "confluent_role_binding" "flink_developer_sr_read" {
  count       = local.kafka_rbac_enabled ? 1 : 0
  principal   = "User:${confluent_service_account.flink_developer.id}"
  role_name   = "DeveloperRead"
  crn_pattern = local.sr_rbac_base
}

resource "confluent_role_binding" "flink_developer_sr_write" {
  count       = local.kafka_rbac_enabled ? 1 : 0
  principal   = "User:${confluent_service_account.flink_developer.id}"
  role_name   = "DeveloperWrite"
  crn_pattern = local.sr_rbac_base
}
