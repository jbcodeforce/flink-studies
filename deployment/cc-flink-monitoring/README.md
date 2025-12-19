# Monitoring Confluent Cloud Flink Statement Metrics

The docker compose starts Prometheus and Grafana.

## Setup

### Configure Prometheus

Update [./prometheus/prometheus.yml](./prometheus/prometheus.yml) with Kafka ClusterId, Schema Registry Id, Confluent Cloud API Key and secret and the compute pools to monitor.

Alternatively, you can copy the configuration from the [Confluent Cloud UI](https://confluent.cloud/settings/metrics/integrations?integration=prometheus). Make sure to select "All resources" instead of the default "All Kafka clusters".

## Start the monitoring

```bash
docker-compose up -d
```

## Access

- **Grafana**: Available at `http://localhost:3010` 
  - Username: `admin`
  - Password: `admin`
- **Prometheus**: Available at `http://localhost:9090`