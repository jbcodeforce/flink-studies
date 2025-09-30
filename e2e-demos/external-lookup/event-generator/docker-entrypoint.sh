#!/bin/bash

# Docker entrypoint for Payment Event Generator
set -e

# Function to wait for Kafka
wait_for_kafka() {
    echo "Waiting for Kafka to be available at $PAYMENT_GEN_KAFKA_BOOTSTRAP_SERVERS..."
    
    # Extract host and port
    IFS=',' read -ra SERVERS <<< "$PAYMENT_GEN_KAFKA_BOOTSTRAP_SERVERS"
    HOST_PORT=${SERVERS[0]}  # Use first server
    HOST=$(echo $HOST_PORT | cut -d':' -f1)
    PORT=$(echo $HOST_PORT | cut -d':' -f2)
    
    # Default port if not specified
    if [ "$PORT" = "$HOST" ]; then
        PORT=9092
    fi
    
    # Wait for Kafka to be ready
    for i in {1..30}; do
        if timeout 5 bash -c "cat < /dev/null > /dev/tcp/$HOST/$PORT" 2>/dev/null; then
            echo "✅ Kafka is ready!"
            return 0
        fi
        echo "⏳ Waiting for Kafka... (attempt $i/30)"
        sleep 2
    done
    
    echo "❌ Timeout waiting for Kafka"
    return 1
}

# Function to validate database connection
validate_database() {
    if [ -n "$DATABASE_URL" ]; then
        echo "🔍 Validating database connection at $DATABASE_URL..."
        payment-generator validate-claims --database-url "$DATABASE_URL" || true
    fi
}

# Function to test Kafka connectivity
test_kafka() {
    echo "🧪 Testing Kafka connectivity..."
    payment-generator test-kafka \
        --kafka-servers "$PAYMENT_GEN_KAFKA_BOOTSTRAP_SERVERS" \
        --topic "$PAYMENT_GEN_KAFKA_TOPIC" \
        --count 3 || {
        echo "⚠️  Kafka test failed, but continuing..."
    }
}

# Function to display startup information
show_startup_info() {
    echo "🚀 Payment Event Generator Starting"
    echo "========================================"
    echo "Kafka Servers: $PAYMENT_GEN_KAFKA_BOOTSTRAP_SERVERS"
    echo "Topic: $PAYMENT_GEN_KAFKA_TOPIC"
    echo "Rate: $PAYMENT_GEN_EVENTS_PER_SECOND events/sec"
    echo "Metrics Port: $PAYMENT_GEN_METRICS_PORT"
    echo "Log Level: $PAYMENT_GEN_LOG_LEVEL"
    echo "========================================"
}

# Main execution
main() {
    show_startup_info
    
    # Wait for dependencies if not in dry run mode
    if [ "$PAYMENT_GEN_DRY_RUN" != "true" ]; then
        wait_for_kafka
        
        # Optional: test Kafka connectivity
        if [ "$TEST_KAFKA" = "true" ]; then
            test_kafka
        fi
        
        # Optional: validate database
        if [ "$VALIDATE_DATABASE" = "true" ]; then
            validate_database
        fi
    fi
    
    # Handle special commands
    case "$1" in
        "scenarios")
            payment-generator scenarios
            ;;
        "test-kafka")
            shift
            payment-generator test-kafka "$@"
            ;;
        "validate-claims")
            shift
            payment-generator validate-claims "$@"
            ;;
        "generate"|"")
            # Default generate command
            if [ "$1" = "generate" ]; then
                shift
            fi
            
            # Build command with environment variables
            CMD="payment-generator generate"
            CMD="$CMD --kafka-servers $PAYMENT_GEN_KAFKA_BOOTSTRAP_SERVERS"
            CMD="$CMD --topic $PAYMENT_GEN_KAFKA_TOPIC"
            CMD="$CMD --rate $PAYMENT_GEN_EVENTS_PER_SECOND"
            CMD="$CMD --metrics-port $PAYMENT_GEN_METRICS_PORT"
            CMD="$CMD --log-level $PAYMENT_GEN_LOG_LEVEL"
            CMD="$CMD --yes"  # Skip interactive confirmation in container environments
            
            # Add optional parameters from environment
            if [ "$PAYMENT_GEN_RUN_DURATION_SECONDS" != "300" ] && [ -n "$PAYMENT_GEN_RUN_DURATION_SECONDS" ]; then
                CMD="$CMD --duration $PAYMENT_GEN_RUN_DURATION_SECONDS"
            fi
            
            if [ "$PAYMENT_GEN_VALID_CLAIM_RATE" != "0.85" ] && [ -n "$PAYMENT_GEN_VALID_CLAIM_RATE" ]; then
                CMD="$CMD --valid-rate $PAYMENT_GEN_VALID_CLAIM_RATE"
            fi
            
            if [ "$PAYMENT_GEN_BURST_MODE" = "true" ]; then
                CMD="$CMD --burst"
                if [ -n "$PAYMENT_GEN_BURST_SIZE" ]; then
                    CMD="$CMD --burst-size $PAYMENT_GEN_BURST_SIZE"
                fi
                if [ -n "$PAYMENT_GEN_BURST_INTERVAL_SECONDS" ]; then
                    CMD="$CMD --burst-interval $PAYMENT_GEN_BURST_INTERVAL_SECONDS"
                fi
            fi
            
            if [ "$PAYMENT_GEN_DRY_RUN" = "true" ]; then
                CMD="$CMD --dry-run"
            fi
            
            if [ "$PAYMENT_GEN_PRINT_EVENTS" = "true" ]; then
                CMD="$CMD --print-events"
            fi
            
            # Add any additional command line arguments
            if [ $# -gt 0 ]; then
                CMD="$CMD $@"
            fi
            
            echo "🎯 Executing: $CMD"
            exec $CMD
            ;;
        *)
            # Pass through any other commands
            exec payment-generator "$@"
            ;;
    esac
}

# Run main function
main "$@"

