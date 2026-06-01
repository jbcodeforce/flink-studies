locals {
  kafka_cluster_id   = data.terraform_remote_state.cc.outputs.kafka_cluster_id
  schema_registry_id = data.terraform_remote_state.cc.outputs.schema_registry_id
  compute_pool_ids   = data.terraform_remote_state.cc.outputs.flink_compute_pool_ids
}
