# Monitoring Confluent Cloud Flink Statement Metrics

The docker compose starts Prometheus and Grafana. [See the getting started with Grafana](https://grafana.com/docs/grafana/latest/fundamentals/getting-started/first-dashboards/get-started-grafana-prometheus/)


## Setup

You can use a hosted Grafana instance at Grafana Cloud or run Grafana locally.

### Configure Prometheus

Update [./prometheus/prometheus.yml](./prometheus/prometheus.yml) with Kafka ClusterId, Schema Registry Id, Confluent Cloud API Key and secret and the compute pools to monitor.

Alternatively, you can copy the configuration from the [Confluent Cloud UI](https://confluent.cloud/settings/metrics/integrations?integration=prometheus). Make sure to select "All resources" instead of the default "All Kafka clusters".

## Start the monitoring

```bash
docker-compose up -d
```

When you run Docker images as containers, changes to these Grafana data are written to the filesystem within the container, which will only persist for as long as the container exist. Here a volume is mounted to keep dashboard definition in grafana folder.
## Access

- **Grafana**: Available at `http://localhost:3010` 
  - Username: `admin`
  - Password: `admin`
- **Prometheus**: Available at `http://localhost:9090`

## Build Dashboards

[See the create dashboard documentation.](https://grafana.com/docs/grafana/latest/visualizations/dashboards/build-dashboards/create-dashboard/)