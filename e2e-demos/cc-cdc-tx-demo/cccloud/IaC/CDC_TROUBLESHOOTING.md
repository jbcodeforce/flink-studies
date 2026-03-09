# CDC Connector Troubleshooting Guide

## Issue: Topics Not Created

If the CDC connector is deployed but topics `card-tx.public.customers` and `card-tx.public.transactions` are not appearing, follow these steps:

### Step 1: Verify Tables Exist in RDS

**Run the verification script:**
```bash
cd IaC
./verify-cdc-setup.sh
```

**Or check manually:**
```bash
# Get RDS endpoint
RDS_ENDPOINT=$(terraform output -raw rds_address)

# Connect and list tables
psql -h $RDS_ENDPOINT -U postgres -d cardtxdb -c '\dt'
```

**Expected output:**
```
 public | customers    | table | postgres
 public | transactions | table | postgres
```

**If tables don't exist:**
```bash
# Create tables using schema.sql
psql -h $(terraform output -raw rds_address) -U postgres -d cardtxdb -f schema.sql

# Or use Terraform
terraform apply -target=null_resource.create_tables
```

### Step 2: Check Connector Status

1. Go to Confluent Cloud UI
2. Navigate to **Connectors**
3. Find connector: `card-tx-cdc-source` (or check with `terraform output cdc_connector_name`)
4. Check **Status** - should be "Running"
5. Review **Logs** for any errors

### Step 3: Understand CDC Topic Creation

**Important:** CDC connectors create topics in these scenarios:

1. **Initial Snapshot**: When the connector first starts, it may perform an initial snapshot of all tables
2. **Change Events**: Topics are created when there are INSERT/UPDATE/DELETE operations on the tables
3. **Empty Tables**: If tables are empty and no changes occur, topics may not be created immediately

### Step 4: Trigger Topic Creation

If tables exist but topics don't appear, insert test data:

```bash
# Connect to RDS
RDS_ENDPOINT=$(terraform output -raw rds_address)
psql -h $RDS_ENDPOINT -U postgres -d cardtxdb

# Insert test data
INSERT INTO customers (account_number, customer_name, email) 
VALUES ('TEST001', 'Test Customer', 'test@example.com');

INSERT INTO transactions (txn_id, account_number, amount, currency, merchant) 
VALUES ('txn-001', 'TEST001', 100.00, 'USD', 'Test Merchant');

# Check if topics were created (in Confluent Cloud UI or CLI)
```

### Step 5: Verify Connector Configuration

Check that the connector is configured correctly:

```bash
# Get connector config from Terraform
terraform show | grep -A 20 "confluent_connector.card_tx_cdc_source"
```

**Key settings to verify:**
- `table.include.list` = `public.customers,public.transactions` ✅
- `database.server.name` = `card-tx` (or your prefix) ✅
- `topic.prefix` = `card-tx` (or your prefix) ✅

**Expected topic names:**
- `${topic.prefix}.${schema}.${table}` = `card-tx.public.customers`
- `${topic.prefix}.${schema}.${table}` = `card-tx.public.transactions`

### Step 6: Check Connector Logs

Common errors in connector logs:

1. **Connection refused/timeout**
   - Verify RDS is publicly accessible: `terraform output rds_endpoint`
   - Check security group allows Confluent Cloud IPs
   - Test connectivity: `nc -zv <rds-endpoint> 5432`

2. **Authentication failed**
   - Verify database credentials in connector config
   - Check `database.user` and `database.password` are correct

3. **Logical replication not enabled**
   - Verify RDS parameter group has `rds.logical_replication = 1`
   ```bash
   RDS_ID=$(terraform output -raw rds_instance_id)
   aws rds describe-db-instances --db-instance-identifier $RDS_ID \
       --query 'DBInstances[0].DBParameterGroups[0].DBParameterGroupName' --output text
   ```

4. **Table not found**
   - Verify tables exist: `psql -h <rds-endpoint> -U postgres -d cardtxdb -c '\dt'`
   - Check `table.include.list` matches your schema

### Step 7: Verify Topics Were Created

**Using Confluent Cloud UI:**
1. Go to **Topics**
2. Search for `card-tx.public.customers` and `card-tx.public.transactions`
3. If they exist, check message count and schema

**Using Confluent CLI:**
```bash
confluent kafka topic list | grep "card-tx.public"
confluent kafka topic describe card-tx.public.customers
confluent kafka topic describe card-tx.public.transactions
```

**Using Terraform outputs:**
```bash
terraform output cdc_customers_topic
terraform output cdc_transactions_topic
```

## Quick Diagnostic Commands

```bash
# 1. Check RDS is accessible
nc -zv $(terraform output -raw rds_address) 5432

# 2. Verify tables exist
./verify-cdc-setup.sh

# 3. Check connector status
terraform output cdc_connector_name
# Then check in Confluent Cloud UI

# 4. Insert test data to trigger topic creation
psql -h $(terraform output -raw rds_address) -U postgres -d cardtxdb <<EOF
INSERT INTO customers (account_number, customer_name) VALUES ('TEST001', 'Test');
INSERT INTO transactions (txn_id, account_number, amount) VALUES ('txn-001', 'TEST001', 100.00);
EOF

# 5. Check topics (wait a few seconds after inserting data)
confluent kafka topic list | grep "card-tx.public"
```

## Still Having Issues?

1. **Check connector logs** in Confluent Cloud UI for specific error messages
2. **Verify all prerequisites** are met (tables exist, RDS accessible, logical replication enabled)
3. **Restart the connector** in Confluent Cloud UI if needed
4. **Review connector configuration** matches your setup

See [DEPLOYMENT.md](./DEPLOYMENT.md) for full deployment instructions.
