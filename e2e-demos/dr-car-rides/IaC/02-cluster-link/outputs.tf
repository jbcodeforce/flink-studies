output "cluster_link_name" {
  description = "Cluster link name (read by export-env.sh and failover-soft.sh)"
  value       = confluent_cluster_link.primary_to_dr.link_name
}

output "mirror_topics" {
  description = "Topics mirrored to DR (rides_raw only; derived topics are re-created by dbt on DR)"
  value       = sort([for m in confluent_kafka_mirror_topic.dr : m.source_kafka_topic[0].topic_name])
}
