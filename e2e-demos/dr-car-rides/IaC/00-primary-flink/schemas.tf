# -----------------------------------------------------------------------------
# rides_raw schemas — owned by Terraform (NOT by Flink/dbt, NOT by the producer)
#
# rides_raw is an external source: it is fed by produce_rides.py (or CDC), so
# dbt only reads it via source(). Registering key/value schemas here means:
#   - Flink can infer the rides_raw table as soon as the topic exists
#   - produce_rides.py runs with auto.register.schemas=False / use.latest.version
#   - no run-order dependency between producer and dbt deploy
#
# Wire format notes:
#   - pickup_ts is epoch milliseconds (integer) -> Flink BIGINT; the rides_clean
#     dbt model derives the TIMESTAMP(3) event-time column from it.
# -----------------------------------------------------------------------------

resource "confluent_schema" "rides_raw_key" {
  schema_registry_cluster {
    id = data.confluent_schema_registry_cluster.primary.id
  }
  rest_endpoint = data.confluent_schema_registry_cluster.primary.rest_endpoint

  subject_name = "rides_raw-key"
  format       = "JSON"
  schema = jsonencode({
    "$schema" = "http://json-schema.org/draft-07/schema#"
    title     = "rides_raw_key"
    type      = "object"
    properties = {
      driver_id = { type = "string" }
    }
    required = ["driver_id"]
  })

  credentials {
    key    = confluent_api_key.producer_sr_primary.id
    secret = confluent_api_key.producer_sr_primary.secret
  }

  # Hard delete on destroy so a re-run of the demo can register the subject again.
  hard_delete = true

  depends_on = [confluent_kafka_topic.rides_raw]

  lifecycle {
    prevent_destroy = false
  }
}

resource "confluent_schema" "rides_raw_value" {
  schema_registry_cluster {
    id = data.confluent_schema_registry_cluster.primary.id
  }
  rest_endpoint = data.confluent_schema_registry_cluster.primary.rest_endpoint

  subject_name = "rides_raw-value"
  format       = "JSON"
  schema = jsonencode({
    "$schema" = "http://json-schema.org/draft-07/schema#"
    title     = "rides_raw_value"
    type      = "object"
    properties = {
      driver_id = { type = "string" }
      ride_id   = { type = "string" }
      seq       = { type = "integer" }
      rider_id  = { type = "string" }
      pickup_ts = { type = "integer", description = "Epoch milliseconds" }
      fare_usd  = { type = "number" }
      status    = { type = "string" }
      city      = { type = "string" }
    }
    required = ["driver_id", "ride_id", "seq", "rider_id", "pickup_ts", "fare_usd", "status", "city"]
  })

  credentials {
    key    = confluent_api_key.producer_sr_primary.id
    secret = confluent_api_key.producer_sr_primary.secret
  }

  hard_delete = true

  depends_on = [confluent_kafka_topic.rides_raw]

  lifecycle {
    prevent_destroy = false
  }
}
