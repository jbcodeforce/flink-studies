# ----------------------------------------
# Secondary environment as secondary
# ----------------------------------------

resource "confluent_environment" "dr" {
  display_name = "${var.prefix}-dr"

  stream_governance {
    package = "ESSENTIALS"
  }

  lifecycle {
    prevent_destroy = false
  }
}


resource "confluent_kafka_cluster" "dr_lkc" {
  display_name = "${var.prefix}-dr-kafka"
  # Enterprise requires HIGH; needed for Cluster Linking on the DR destination.
  availability = "HIGH"
  cloud        = "AWS"
  region       = var.aws_dr_region

  enterprise {}

  environment {
    id = confluent_environment.dr.id
  }

  lifecycle {
    prevent_destroy = false
  }
}


resource "confluent_service_account" "cluster_link_sa" {
  display_name = "${var.prefix}-clink-manager"
}

resource "confluent_role_binding" "source_admin" {
  principal   = "User:${confluent_service_account.cluster_link_sa.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = data.confluent_kafka_cluster.primary_lkc.rbac_crn
}

resource "confluent_role_binding" "destination_admin" {
  principal   = "User:${confluent_service_account.cluster_link_sa.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.dr_lkc.rbac_crn
}

resource "confluent_api_key" "source" {
  display_name = "${var.prefix}-clink-source-key"

  owner {
    id          = confluent_service_account.cluster_link_sa.id
    api_version = confluent_service_account.cluster_link_sa.api_version
    kind        = confluent_service_account.cluster_link_sa.kind
  }

  managed_resource {
    id          = data.confluent_kafka_cluster.primary_lkc.id
    api_version = data.confluent_kafka_cluster.primary_lkc.api_version
    kind        = data.confluent_kafka_cluster.primary_lkc.kind

    environment {
      id = data.confluent_environment.primary_env.id
    }
  }

  depends_on = [confluent_role_binding.source_admin]
}

resource "confluent_api_key" "destination" {
  display_name = "${var.prefix}-clink-destination-key"

  owner {
    id          = confluent_service_account.cluster_link_sa.id
    api_version = confluent_service_account.cluster_link_sa.api_version
    kind        = confluent_service_account.cluster_link_sa.kind
  }

  managed_resource {
    id          = confluent_kafka_cluster.dr_lkc.id
    api_version = confluent_kafka_cluster.dr_lkc.api_version
    kind        = confluent_kafka_cluster.dr_lkc.kind

    environment {
      id = confluent_environment.dr.id
    }
  }

  depends_on = [confluent_role_binding.destination_admin]
}
