#!/bin/bash

# Flink SQL Deduplication Runner
# This script helps run the Flink SQL deduplication script in different environments

set -e

SQL_FILE="flink-deduplication.sql"
NAMESPACE="${FLINK_NAMESPACE:-flink}"

echo "🚀 Flink SQL Deduplication Demo"
echo "==============================="

# Check if SQL file exists
if [ ! -f "${SQL_FILE}" ]; then
    echo "❌ Error: ${SQL_FILE} not found in current directory!"
    echo "   Please run this script from the dedup-demo directory."
    exit 1
fi

echo "📄 SQL File: ${SQL_FILE}"
echo ""

# Check deployment type
echo "🏗️  Deployment Options:"
echo "1. Kubernetes (Confluent Platform for Flink)"
echo "2. Local Flink installation"
echo ""

read -p "Select deployment type (1 or 2): " deployment_type

case $deployment_type in
    1)
        echo "🎯 Selected: Kubernetes (Confluent Platform for Flink)"
        echo ""
        
        # Check if kubectl is available
        if ! command -v kubectl &> /dev/null; then
            echo "❌ Error: kubectl not found!"
            echo "   Please install kubectl to interact with Kubernetes."
            exit 1
        fi
        
        # Find Flink pods in the namespace
        echo "🔍 Looking for Flink pods in namespace '${NAMESPACE}'..."
        FLINK_PODS=$(kubectl get pods -n "${NAMESPACE}" -l app=flink --no-headers -o custom-columns=":metadata.name" 2>/dev/null || true)
        
        if [ -z "$FLINK_PODS" ]; then
            echo "❌ No Flink pods found in namespace '${NAMESPACE}'"
            echo "   Try checking available namespaces:"
            echo "   kubectl get namespaces"
            echo ""
            echo "   Or specify a different namespace:"
            echo "   FLINK_NAMESPACE=your-namespace ./run-flink-dedup.sh"
            exit 1
        fi
        
        echo "📦 Found Flink pods:"
        echo "$FLINK_PODS"
        echo ""
        
        # Use the first Flink pod (usually the job manager)
        FLINK_POD=$(echo "$FLINK_PODS" | head -n1)
        echo "🎯 Using Flink pod: ${FLINK_POD}"
        echo ""
        
        echo "📝 Instructions:"
        echo "1. The SQL file will be copied to the Flink pod"
        echo "2. You'll be connected to the Flink SQL CLI"
        echo "3. The deduplication script will be loaded automatically"
        echo ""
        echo "🔧 Useful commands in Flink SQL CLI:"
        echo "   - Check deduplication stats: SELECT * FROM deduplication_stats;"
        echo "   - View current products: SELECT * FROM current_product_state;"
        echo "   - Monitor events: SELECT * FROM product_events_flattened LIMIT 10;"
        echo "   - Exit: quit;"
        echo ""
        
        read -p "Press Enter to copy SQL file and start Flink SQL CLI..."
        
        # Copy SQL file to the Flink pod
        echo "📤 Copying ${SQL_FILE} to pod ${FLINK_POD}..."
        kubectl cp "${SQL_FILE}" "${NAMESPACE}/${FLINK_POD}:/tmp/${SQL_FILE}"
        
        # Execute the SQL file in Flink SQL CLI
        echo "🏃 Starting Flink SQL CLI and executing deduplication script..."
        kubectl exec -it "${FLINK_POD}" -n "${NAMESPACE}" -- /opt/flink/bin/sql-client.sh -f "/tmp/${SQL_FILE}"
        ;;
        
    2)
        echo "🎯 Selected: Local Flink installation"
        echo ""
        
        FLINK_HOME=${FLINK_HOME:-"/opt/flink"}
        
        # Check if Flink is available locally
        if ! command -v sql-client.sh &> /dev/null && ! command -v "${FLINK_HOME}/bin/sql-client.sh" &> /dev/null; then
            echo "❌ Error: Flink SQL client not found!"
            echo "   Please ensure Flink is installed and FLINK_HOME is set correctly."
            echo "   Current FLINK_HOME: ${FLINK_HOME}"
            echo ""
            echo "   Installation options:"
            echo "   1. Download Flink from https://flink.apache.org/downloads/"
            echo "   2. Extract and set FLINK_HOME environment variable"
            echo "   3. Or use: export FLINK_HOME=/path/to/your/flink"
            exit 1
        fi
        
        # Determine the correct SQL client path
        if command -v sql-client.sh &> /dev/null; then
            SQL_CLIENT="sql-client.sh"
        else
            SQL_CLIENT="${FLINK_HOME}/bin/sql-client.sh"
        fi
        
        echo "🔧 Using SQL Client: ${SQL_CLIENT}"
        echo "🏠 Flink Home: ${FLINK_HOME}"
        echo ""
        
        read -p "Press Enter to start Flink SQL CLI with deduplication script..."
        
        # Start Flink SQL CLI and source the SQL file
        echo "🏃 Starting Flink SQL CLI..."
        "${SQL_CLIENT}" -f "${SQL_FILE}"
        ;;
        
    *)
        echo "❌ Invalid selection. Please choose 1 or 2."
        exit 1
        ;;
esac 