resource "confluent_service_account" "metrics_viewer" {
  display_name = "${var.prefix}-metrics-viewer"
  description  = "MetricsViewer for Prometheus scrape of Confluent Cloud Flink metrics"
}

data "confluent_organization" "org" {}

resource "confluent_role_binding" "metrics_viewer" {
  principal   = "User:${confluent_service_account.metrics_viewer.id}"
  role_name   = "MetricsViewer"
  crn_pattern = data.confluent_organization.org.resource_name
}

resource "confluent_api_key" "metrics" {
  display_name = "${var.prefix}-metrics-prometheus"
  description  = "Cloud API key for Prometheus Metrics API export"
  owner {
    id          = confluent_service_account.metrics_viewer.id
    api_version = confluent_service_account.metrics_viewer.api_version
    kind        = confluent_service_account.metrics_viewer.kind
  }

  lifecycle {
    prevent_destroy = true
  }
}
