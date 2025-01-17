resource "confluent_flink_compute_pool" "default" {
  display_name     = "${var.lab_name}-default"
  cloud            =  upper(data.confluent_flink_region.flink_region.cloud)
  region           =  data.confluent_flink_region.flink_region.region
  max_cfu          = 50
  environment {
     id =  confluent_environment.env.id
  }
}

resource "confluent_service_account" "flink-app" {
  display_name = "${var.lab_name}-flink-app"
  description  = "Service account as which Flink Statements run in the environment"
}

resource "confluent_service_account" "flink-developer-sa" {
  display_name = "${var.lab_name}-fd-sa"
  description  = "Service account to deploy Flink Statements in the environment"
}

resource "confluent_role_binding" "flink-developer-sa-flink-developer" {
  principal   = "User:${confluent_service_account.flink-developer-sa.id}"
  role_name   = "FlinkDeveloper"
  //crn_pattern = "${data.confluent_organization.my_org.resource_name}/environment=${var.cc_environment_id}"
  crn_pattern=confluent_environment.env.resource_name
}

resource "confluent_role_binding" "app-manager-assigner" {
  principal   = "User:${confluent_service_account.flink-developer-sa.id}"
  role_name   = "Assigner"
  crn_pattern = "${data.confluent_organization.my_org.resource_name}/service-account=${confluent_service_account.flink-app.id}"
}

resource "confluent_api_key" "flink-developer-sa-flink-api-key" {
  display_name = "flink-statement-runner-flink-api-key"
  description  = "Flink API Key that is owned by 'flink-developer-sa' service account"
  owner {
    id          = confluent_service_account.flink-developer-sa.id
    api_version = confluent_service_account.flink-developer-sa.api_version
    kind        = confluent_service_account.flink-developer-sa.kind
  }

  managed_resource {
    id          = data.confluent_flink_region.flink_region.id
    api_version = data.confluent_flink_region.flink_region.api_version
    kind        = data.confluent_flink_region.flink_region.kind

    environment {
       id =  confluent_environment.env.id
    }
  }
}

resource "confluent_role_binding" "flink-app-clusteradmin" {
  principal   = "User:${confluent_service_account.flink-app.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.standard.rbac_crn
}

data "confluent_schema_registry_cluster" "env" {
  environment {
    id = confluent_environment.env.id
  }
}

resource "confluent_role_binding" "flink-app-sr-read" {
  principal   = "User:${confluent_service_account.flink-app.id}"
  role_name   = "DeveloperRead"
  crn_pattern = "${data.confluent_schema_registry_cluster.env.resource_name}/subject=*"
}

resource "confluent_role_binding" "flink-app-sr-write" {
  principal   = "User:${confluent_service_account.flink-app.id}"
  role_name   = "DeveloperWrite"
  crn_pattern = "${data.confluent_schema_registry_cluster.env.resource_name}/subject=*"
}

resource "confluent_api_key" "flink-app-flink-api-key" {
  display_name = "flink-app-flink-api-key"
  description  = "Flink API Key that is owned by 'flink-app' service account"
  owner {
    id          = confluent_service_account.flink-app.id
    api_version = confluent_service_account.flink-app.api_version
    kind        = confluent_service_account.flink-app.kind
  }

  managed_resource {
    id          = data.confluent_flink_region.flink_region.id
    api_version = data.confluent_flink_region.flink_region.api_version
    kind        = data.confluent_flink_region.flink_region.kind

    environment {
       id =  confluent_environment.env.id
    }
  }
}