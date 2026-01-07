# Import existing j9r-env resources into Terraform state
# These resources already exist in Confluent Cloud
# Run: terraform plan to verify imports before apply

# Environment
import {
  to = confluent_environment.env
  id = "env-nknqp3"
}

# Environment Manager Service Account
import {
  to = confluent_service_account.env-manager
  id = "sa-7vvrvw"
}

# Kafka Cluster (format: env-id/cluster-id)
import {
  to = confluent_kafka_cluster.standard
  id = "env-nknqp3/lkc-3mnm0m"
}

# App Manager Service Account
import {
  to = confluent_service_account.app-manager
  id = "sa-3oy222"
}

# Flink App Service Account (runtime principal)
import {
  to = confluent_service_account.flink-app
  id = "sa-111z1z"
}

# Flink Developer Service Account
import {
  to = confluent_service_account.flink-developer-sa
  id = "sa-z8828d"
}

# Flink Compute Pools (format: env-id/pool-id)

import {
  to = confluent_flink_compute_pool.data-generation
  id = "env-nknqp3/lfcp-r80731"
}

import {
  to = confluent_flink_compute_pool.dev-j9r-pool
  id = "env-nknqp3/lfcp-xvrvmz"
}
