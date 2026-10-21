#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NETWORK_NAME="flink-network"

# Function to check if a container exists
container_exists() {
  local name="$1"
  container ps -a --format '{{.Names}}' 2>/dev/null | grep -qw "$name" || false
}

# Function to check if a network exists
network_exists() {
  local name="$1"
  container network ls --format '{{.Name}}' 2>/dev/null | grep -qw "$name" || false
}

start_stack() {
  echo "=== Starting Flink & Kafka environment with Apple container engine ==="

  # Create settings directory if not present for sql-client volume mount
  mkdir -p "${SCRIPT_DIR}/settings"

  # Create container network if it does not exist
  if ! network_exists "${NETWORK_NAME}"; then
    echo "Creating network: ${NETWORK_NAME}..."
    container network create "${NETWORK_NAME}" || true
  fi

  # 1. Start Kafka Broker (KRaft Mode)
  if container_exists "broker"; then
    echo "Stopping and removing existing 'broker' container..."
    container stop broker 2>/dev/null || true
    container rm broker 2>/dev/null || true
  fi

  echo "Starting Kafka broker..."
  container run -d \
    --name broker \
    --hostname broker \
    --network "${NETWORK_NAME}" \
    -p 9092:9092 \
    -e KAFKA_BROKER_ID=1 \
    -e KAFKA_LISTENER_SECURITY_PROTOCOL_MAP="CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT" \
    -e KAFKA_ADVERTISED_LISTENERS="PLAINTEXT://broker:29092,PLAINTEXT_HOST://localhost:9092" \
    -e KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR=1 \
    -e KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS=0 \
    -e KAFKA_TRANSACTION_STATE_LOG_MIN_ISR=1 \
    -e KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR=1 \
    -e KAFKA_PROCESS_ROLES="broker,controller" \
    -e KAFKA_NODE_ID=1 \
    -e KAFKA_CONTROLLER_QUORUM_VOTERS="1@broker:29093" \
    -e KAFKA_LISTENERS="PLAINTEXT://broker:29092,CONTROLLER://broker:29093,PLAINTEXT_HOST://0.0.0.0:9092" \
    -e KAFKA_INTER_BROKER_LISTENER_NAME="PLAINTEXT" \
    -e KAFKA_CONTROLLER_LISTENER_NAMES="CONTROLLER" \
    -e KAFKA_LOG_DIRS="/tmp/kraft-combined-logs" \
    -e CLUSTER_ID="MkU3OEVBNTcwNTJENDM2Qk" \
    confluentinc/cp-kafka:7.8.0

  # 2. Start Flink JobManager
  if container_exists "flink-jobmanager"; then
    echo "Stopping and removing existing 'flink-jobmanager' container..."
    container stop flink-jobmanager 2>/dev/null || true
    container rm flink-jobmanager 2>/dev/null || true
  fi

  echo "Starting Flink JobManager..."
  FLINK_JM_PROPS=$(cat <<'EOF'
jobmanager.rpc.address: flink-jobmanager
rest.bind-port: 9081
EOF
)
  container run -d \
    --name flink-jobmanager \
    --hostname flink-jobmanager \
    --network "${NETWORK_NAME}" \
    -p 9081:9081 \
    -e FLINK_PROPERTIES="${FLINK_JM_PROPS}" \
    cnfldemos/flink-kafka:1.19.1-scala_2.12-java17 \
    jobmanager

  # 3. Start Flink TaskManager
  if container_exists "flink-taskmanager"; then
    echo "Stopping and removing existing 'flink-taskmanager' container..."
    container stop flink-taskmanager 2>/dev/null || true
    container rm flink-taskmanager 2>/dev/null || true
  fi

  echo "Starting Flink TaskManager..."
  FLINK_TM_PROPS=$(cat <<'EOF'
jobmanager.rpc.address: flink-jobmanager
taskmanager.numberOfTaskSlots: 10
EOF
)
  container run -d \
    --name flink-taskmanager \
    --hostname flink-taskmanager \
    --network "${NETWORK_NAME}" \
    -e FLINK_PROPERTIES="${FLINK_TM_PROPS}" \
    cnfldemos/flink-kafka:1.19.1-scala_2.12-java17 \
    taskmanager

  # 4. Start Flink SQL Client (daemonized or run interactively)
  if container_exists "flink-sql-client"; then
    echo "Stopping and removing existing 'flink-sql-client' container..."
    container stop flink-sql-client 2>/dev/null || true
    container rm flink-sql-client 2>/dev/null || true
  fi

  echo "Starting Flink SQL Client..."
  container run -d \
    --name flink-sql-client \
    --hostname flink-sql-client \
    --network "${NETWORK_NAME}" \
    -v "${SCRIPT_DIR}/settings:/settings" \
    -e FLINK_JOBMANAGER_HOST=flink-jobmanager \
    cnfldemos/flink-sql-client-kafka:1.19.1-scala_2.12-java17

  echo ""
  echo "All containers started successfully!"
  echo " - Flink Dashboard: http://localhost:9081"
  echo " - Kafka Broker:    localhost:9092"
  echo ""
  echo "To attach to the Flink SQL Client CLI, run:"
  echo "  container exec -it flink-sql-client /docker-entrypoint.sh sql-client"
}

stop_stack() {
  echo "=== Stopping Flink & Kafka containers ==="
  for c in flink-sql-client flink-taskmanager flink-jobmanager broker; do
    if container_exists "$c"; then
      echo "Stopping $c..."
      container stop "$c" 2>/dev/null || true
      container rm "$c" 2>/dev/null || true
    fi
  done
  echo "All containers stopped and removed."
}

status_stack() {
  echo "=== Container Status ==="
  container ps -a --filter "name=broker" --filter "name=flink"
}

sql_client() {
  echo "=== Connecting to Flink SQL Client CLI ==="
  container exec -it flink-sql-client /docker-entrypoint.sh sql-client
}

case "${1:-start}" in
  start)
    start_stack
    ;;
  stop)
    stop_stack
    ;;
  restart)
    stop_stack
    start_stack
    ;;
  status)
    status_stack
    ;;
  sql-client|sql|cli)
    sql_client
    ;;
  *)
    echo "Usage: $0 {start|stop|restart|status|sql-client}"
    exit 1
    ;;
esac
