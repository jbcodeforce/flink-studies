export FLINK_HOME=$PWD/../../../deployment/product-tar/flink-2.1.1
export PATH=$PATH:$FLINK_HOME/bin

# Start the cluster
$FLINK_HOME/bin/start-cluster.sh

# Wait for JobManager REST endpoint to become available (timeout in 30 seconds)
echo "Waiting for Flink JobManager REST endpoint to be available..."
MAX_ATTEMPTS=30
SLEEP_SECONDS=1
SUCCESS=0
for ((i=1; i<=MAX_ATTEMPTS; i++)); do
  if curl -s http://localhost:8081/overview > /dev/null; then
    echo "Flink JobManager is up!"
    SUCCESS=1
    break
  else
    sleep $SLEEP_SECONDS
  fi
done

if [ $SUCCESS -ne 1 ]; then
  echo "Flink JobManager did not start within expected time. Exiting."
  exit 1
fi

# Then sql client in interactive mode
$FLINK_HOME/bin/sql-client.sh embedded -i ./oss-flink/init_session.sql