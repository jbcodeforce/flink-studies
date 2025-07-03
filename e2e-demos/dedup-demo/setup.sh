#!/bin/bash

# Deduplication Demo Setup Script

echo "🚀 Setting up Deduplication Demo..."

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is required but not installed."
    exit 1
fi

# Check if uv is installed
if ! command -v uv &> /dev/null; then
    echo "❌ uv is required but not installed."
    echo "   Install uv: https://docs.astral.sh/uv/getting-started/installation/"
    exit 1
fi


# Check if Kafka is running (optional check)
echo "🔍 Checking Kafka connection..."
timeout 5 bash -c 'cat < /dev/null > /dev/tcp/localhost/9092' 2>/dev/null
if [ $? -eq 0 ]; then
    echo "✅ Kafka is running on localhost:9092"
else
    echo "⚠️  Warning: Cannot connect to Kafka on localhost:9092"
    echo "   Make sure Kafka is running before starting the producer"
fi

# Create the Kafka topic (if kafka-topics is available)
if command -v kafka-topics &> /dev/null; then
    echo "🎯 Creating Kafka topic 'products'..."
    kafka-topics --create --topic products --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1 2>/dev/null || echo "   Topic may already exist"
else
    echo "⚠️  kafka-topics command not found. You may need to create the topic manually:"
    echo "   kafka-topics --create --topic products --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1"
fi

echo ""
echo "✅ Setup complete!"
echo ""
echo "To monitor the topic:"
echo "   kafka-console-consumer --topic products --bootstrap-server localhost:9092 --from-beginning"
echo ""
echo "Alternative - to connect to k8s Kafka cluster locally:"
echo "   kubectl port-forward service/kafka 9092:9092 -n confluent"
echo "   export KAFKA_BOOTSTRAP_SERVERS=localhost:9092"
echo ""
echo "Environment variables you can set:"
echo "   export KAFKA_BOOTSTRAP_SERVERS=localhost:9092"
echo "   export KAFKA_PRODUCT_TOPIC=products" 