#!/bin/bash

# Simple script to verify DuckDB table creation and data

DB_PATH="/tmp/fraud_analysis.db"

echo "=== DuckDB Verification ==="
echo "Database path: $DB_PATH"
echo ""

if [ ! -f "$DB_PATH" ]; then
    echo "❌ Database file does not exist: $DB_PATH"
    echo "Run the FraudCountTableApiJob first to create the database."
    exit 1
fi

echo "✅ Database file exists"
echo ""

echo "=== Table Structure ==="
duckdb "$DB_PATH" "DESCRIBE fraud_analysis;"
echo ""

echo "=== Table Data ==="
duckdb "$DB_PATH" "SELECT * FROM fraud_analysis ORDER BY analysis_date DESC, analysis_timestamp DESC;"
echo ""

echo "=== Record Count ==="
duckdb "$DB_PATH" "SELECT COUNT(*) as total_records FROM fraud_analysis;"
echo ""

echo "=== Latest Analysis ==="
duckdb "$DB_PATH" "
SELECT 
    analysis_date,
    total_fraudulent_loans,
    analysis_timestamp as last_updated
FROM fraud_analysis 
WHERE analysis_type = 'fraud_count_analysis'
ORDER BY analysis_date DESC 
LIMIT 1;
"

echo ""
echo "=== Verification Complete ==="
