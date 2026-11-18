#!/usr/bin/env bash
# Start / stop the Iceberg lab using the Apple `container` CLI.
# Translation of docker-compose.yaml in this folder.
#
# Usage: ./start-containers.sh [up|down|status]   (default: up)
set -euo pipefail

cd "$(dirname "$0")"

NETWORK=iceberg_net
ACCESS_KEY="${AWS_ACCESS_KEY_ID:-admin}"
SECRET_KEY="${AWS_SECRET_ACCESS_KEY:-password}"
REGION=us-east-1

SPARK_IMAGE=tabulario/spark-iceberg
REST_IMAGE=apache/iceberg-rest-fixture
STORE_IMAGE=rustfs/rustfs:1.0.0

CONTAINERS=(spark-iceberg iceberg-rest object-store create-bucket)

remove_container() {
  # stop + delete if it exists (ignore errors when it doesn't)
  container stop "$1" >/dev/null 2>&1 || true
  container delete "$1" >/dev/null 2>&1 || true
}

down() {
  for c in "${CONTAINERS[@]}"; do
    remove_container "$c"
  done
  container network delete "$NETWORK" >/dev/null 2>&1 || true
  echo "Stopped and removed iceberg containers."
}

status() {
  container list --all | grep -E "^ID|$(IFS='|'; echo "${CONTAINERS[*]}")" || true
}

up() {
  container system status >/dev/null 2>&1 || container system start

  mkdir -p warehouse notebooks

  # Network (compose: iceberg_net)
  container network inspect "$NETWORK" >/dev/null 2>&1 || container network create "$NETWORK"

  # Clean previous runs so names can be reused
  for c in "${CONTAINERS[@]}"; do remove_container "$c"; done

  # --- object-store (S3 compatible, RustFS) --------------------------------
  container run -d --name object-store \
    --network "$NETWORK" \
    -p 9000:9000 -p 9001:9001 \
    -e RUSTFS_ACCESS_KEY="$ACCESS_KEY" \
    -e RUSTFS_SECRET_KEY="$SECRET_KEY" \
    -e RUSTFS_OBS_LOG_STDOUT_ENABLED=true \
    -e RUSTFS_SERVER_DOMAINS=minio \
    "$STORE_IMAGE"

  # compose healthcheck equivalent: wait for /health/ready (5s interval, 5 retries+)
  echo -n "Waiting for object-store to be ready"
  for _ in $(seq 1 30); do
    if curl -sf http://localhost:9000/health/ready >/dev/null 2>&1; then
      echo " ok"
      break
    fi
    echo -n "."
    sleep 2
  done
  curl -sf http://localhost:9000/health/ready >/dev/null || { echo " object-store not healthy"; exit 1; }

  # --- create-bucket (one-shot job) ----------------------------------------
  container run --rm --name create-bucket \
    --network "$NETWORK" \
    --entrypoint /bin/sh \
    "$STORE_IMAGE" \
    -c "curl -sf -o /dev/null --aws-sigv4 aws:amz:${REGION}:s3 --user ${ACCESS_KEY}:${SECRET_KEY} --head http://object-store:9000/warehouse || \
        curl -sSf --aws-sigv4 aws:amz:${REGION}:s3 --user ${ACCESS_KEY}:${SECRET_KEY} -X PUT http://object-store:9000/warehouse"

  # --- iceberg REST catalog ------------------------------------------------
  container run -d --name iceberg-rest \
    --network "$NETWORK" \
    -p 8181:8181 \
    -e AWS_ACCESS_KEY_ID="$ACCESS_KEY" \
    -e AWS_SECRET_ACCESS_KEY="$SECRET_KEY" \
    -e AWS_REGION="$REGION" \
    -e CATALOG_WAREHOUSE=s3://warehouse/ \
    -e CATALOG_IO__IMPL=org.apache.iceberg.aws.s3.S3FileIO \
    -e CATALOG_S3_ENDPOINT=http://object-store:9000 \
    -e CATALOG_S3_PATH__STYLE__ACCESS=true \
    "$REST_IMAGE"

  # --- spark-iceberg -------------------------------------------------------
  # Note: compose also has `build: spark/`, but that directory does not exist,
  # so the prebuilt image is used.
  container run -d --name spark-iceberg \
    --network "$NETWORK" \
    -p 8888:8888 -p 8080:8080 -p 10000:10000 -p 10001:10001 \
    -v "$PWD/warehouse:/home/iceberg/warehouse" \
    -v "$PWD/notebooks:/home/iceberg/notebooks/notebooks" \
    -e AWS_ACCESS_KEY_ID="$ACCESS_KEY" \
    -e AWS_SECRET_ACCESS_KEY="$SECRET_KEY" \
    -e AWS_REGION="$REGION" \
    "$SPARK_IMAGE"

  # The compose file gives object-store the network aliases `minio` and
  # `warehouse.minio` (virtual-hosted-style S3 expected by spark-iceberg).
  # `container` has no network aliases, so map them in the spark container's /etc/hosts.
  STORE_IP=$(container inspect object-store \
    | grep -o '"ipv4Address" *: *"[0-9.]*' | head -1 | grep -o '[0-9.]*$')
  if [ -n "${STORE_IP:-}" ]; then
    container exec spark-iceberg sh -c \
      "echo '${STORE_IP} minio warehouse.minio' >> /etc/hosts"
    echo "Mapped minio / warehouse.minio -> ${STORE_IP} in spark-iceberg"
  else
    echo "WARNING: could not determine object-store IP; add the minio aliases to spark-iceberg /etc/hosts manually" >&2
  fi

  cat <<EOF

Iceberg lab is up:
  Jupyter / Spark UI : http://localhost:8888 , http://localhost:8080
  Iceberg REST       : http://localhost:8181
  Object store (S3)  : http://localhost:9000  (console http://localhost:9001, ${ACCESS_KEY}/${SECRET_KEY})
EOF
}

case "${1:-up}" in
  up) up ;;
  down) down ;;
  status) status ;;
  *) echo "Usage: $0 [up|down|status]" >&2; exit 1 ;;
esac
