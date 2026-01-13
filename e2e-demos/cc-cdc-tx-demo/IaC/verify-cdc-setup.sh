#!/bin/bash
# Verify CDC Connector Setup
# Checks if tables exist in RDS and if CDC topics are created

set -e

cd "$(dirname "$0")"

echo "=========================================="
echo "CDC Connector Setup Verification"
echo "=========================================="
echo ""

# Get RDS connection info
RDS_ENDPOINT=$(terraform output -raw rds_address 2>/dev/null || echo "")
RDS_PORT="5432"  # Default PostgreSQL port
DB_NAME=$(terraform output -raw rds_database_name 2>/dev/null || echo "cardtxdb")

# Get DB user from terraform.tfvars or use default
if [ -f "terraform.tfvars" ]; then
    DB_USER=$(grep -E '^\s*db_username\s*=' terraform.tfvars | awk -F'"' '{print $2}' | head -n1 || echo "postgres")
else
    DB_USER="postgres"
fi

if [ -z "$RDS_ENDPOINT" ]; then
    echo "ERROR: Could not get RDS endpoint. Is RDS deployed?"
    exit 1
fi

echo "RDS Endpoint: $RDS_ENDPOINT"
echo "Database: $DB_NAME"
echo ""

# Check if psql is available
if ! command -v psql &> /dev/null; then
    echo "WARNING: psql not found. Cannot verify tables in RDS."
    echo "Install psql: brew install postgresql (macOS) or sudo apt-get install postgresql-client (Linux)"
    echo ""
    echo "To verify tables manually, connect to RDS and run:"
    echo "  psql -h $RDS_ENDPOINT -U $DB_USER -d $DB_NAME -c '\dt'"
    echo ""
else
    echo "Checking if tables exist in RDS..."
    echo ""
    
    # Get password from terraform.tfvars or ask user
    if [ -f "terraform.tfvars" ]; then
        DB_PASSWORD=$(grep -E '^\s*db_password\s*=' terraform.tfvars | awk -F'"' '{print $2}' | head -n1)
    fi
    
    if [ -z "$DB_PASSWORD" ]; then
        echo "Enter database password for user $DB_USER:"
        read -s DB_PASSWORD
        echo ""
    fi
    
    # Check if tables exist
    export PGPASSWORD="$DB_PASSWORD"
    
    echo "Tables in database '$DB_NAME':"
    psql -h "$RDS_ENDPOINT" -p "$RDS_PORT" -U "$DB_USER" -d "$DB_NAME" -c "\dt" 2>&1 || {
        echo ""
        echo "ERROR: Could not connect to database. Check:"
        echo "  1. RDS is running and accessible"
        echo "  2. Security group allows your IP"
        echo "  3. Password is correct"
        exit 1
    }
    
    echo ""
    echo "Checking for required tables..."
    
    # Check for customers table
    CUSTOMERS_EXISTS=$(psql -h "$RDS_ENDPOINT" -p "$RDS_PORT" -U "$DB_USER" -d "$DB_NAME" -tAc \
        "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'customers');" 2>/dev/null || echo "f")
    
    # Check for transactions table
    TRANSACTIONS_EXISTS=$(psql -h "$RDS_ENDPOINT" -p "$RDS_PORT" -U "$DB_USER" -d "$DB_NAME" -tAc \
        "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'transactions');" 2>/dev/null || echo "f")
    
    if [ "$CUSTOMERS_EXISTS" == "t" ]; then
        echo "  ✅ customers table exists"
    else
        echo "  ❌ customers table NOT found"
        echo "     Run: psql -h $RDS_ENDPOINT -U $DB_USER -d $DB_NAME -f schema.sql"
    fi
    
    if [ "$TRANSACTIONS_EXISTS" == "t" ]; then
        echo "  ✅ transactions table exists"
    else
        echo "  ❌ transactions table NOT found"
        echo "     Run: psql -h $RDS_ENDPOINT -U $DB_USER -d $DB_NAME -f schema.sql"
    fi
    
    echo ""
    
    # Check table row counts
    if [ "$CUSTOMERS_EXISTS" == "t" ]; then
        CUSTOMER_COUNT=$(psql -h "$RDS_ENDPOINT" -p "$RDS_PORT" -U "$DB_USER" -d "$DB_NAME" -tAc \
            "SELECT COUNT(*) FROM customers;" 2>/dev/null || echo "0")
        echo "  customers table has $CUSTOMER_COUNT rows"
    fi
    
    if [ "$TRANSACTIONS_EXISTS" == "t" ]; then
        TRANSACTION_COUNT=$(psql -h "$RDS_ENDPOINT" -p "$RDS_PORT" -U "$DB_USER" -d "$DB_NAME" -tAc \
            "SELECT COUNT(*) FROM transactions;" 2>/dev/null || echo "0")
        echo "  transactions table has $TRANSACTION_COUNT rows"
    fi
    
    unset PGPASSWORD
fi

echo ""
echo "=========================================="
echo "CDC Connector Status"
echo "=========================================="
echo ""

# Get connector info
CONNECTOR_NAME=$(terraform output -raw cdc_connector_name 2>/dev/null || echo "")
PREFIX=$(terraform show -json 2>/dev/null | jq -r '.values.root_module.resources[]? | select(.type=="var.prefix") | .values.value // "card-tx"' | head -n1)

if [ -z "$CONNECTOR_NAME" ]; then
    CONNECTOR_NAME="${PREFIX}-cdc-source"
fi

echo "Expected connector name: $CONNECTOR_NAME"
echo "Expected topics:"
echo "  - ${PREFIX}.public.customers"
echo "  - ${PREFIX}.public.transactions"
echo ""

echo "To check connector status in Confluent Cloud:"
echo "  1. Go to Confluent Cloud UI"
echo "  2. Navigate to Connectors"
echo "  3. Find connector: $CONNECTOR_NAME"
echo "  4. Check Status and Logs"
echo ""

echo "To check topics via Confluent CLI:"
echo "  confluent kafka topic list"
echo "  confluent kafka topic describe ${PREFIX}.public.customers"
echo "  confluent kafka topic describe ${PREFIX}.public.transactions"
echo ""

echo "Common Issues:"
echo "  1. Tables don't exist → Run schema.sql to create them"
echo "  2. Connector not running → Check connector logs in Confluent Cloud"
echo "  3. Topics not created → Connector may be waiting for table changes"
echo "  4. Connection errors → Verify RDS is publicly accessible and security groups allow Confluent Cloud IPs"
echo ""

echo "=========================================="
