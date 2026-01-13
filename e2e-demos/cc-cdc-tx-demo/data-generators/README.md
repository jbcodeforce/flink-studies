# Test Data Generator

Python script to generate test customers and transactions for the Card Transaction Demo.

## Installation

This project uses [uv](https://github.com/astral-sh/uv) for dependency management.

```bash
# Install uv if you haven't already
curl -LsSf https://astral.sh/uv/install.sh | sh

# Install dependencies
uv sync
```

## Usage

### One-Shot Mode (Generate 10 customers + 10 transactions)

```bash
uv run generate_test_data.py \
  --db-host <rds-endpoint> \
  --db-name cardtxdb \
  --db-user postgres \
  --db-password <password>
```

### Continuous Mode (Generate transactions forever)

```bash
uv run generate_test_data.py \
  --db-host <rds-endpoint> \
  --db-name cardtxdb \
  --db-user postgres \
  --db-password <password> \
  --run-forever \
  --interval 5
```

### Using Environment Variables

```bash
export DB_HOST=<rds-endpoint>
export DB_NAME=cardtxdb
export DB_USER=postgres
export DB_PASSWORD=<password>

# One-shot
uv run generate_test_data.py

# Continuous
uv run generate_test_data.py --run-forever
```

### Getting RDS Endpoint from Terraform

```bash
cd ../IaC
export DB_HOST=$(terraform output -raw rds_address)
export DB_PASSWORD=<your-password>
export DB_NAME=cardtxdb
export DB_USER=postgres

cd ../data-generators
uv run generate_test_data.py --run-forever
```

### Add a Single Customer

Add a single customer to the database. Useful for testing CDC insert operations.

```bash
uv run generate_test_data.py \
  --db-host <rds-endpoint> \
  --db-name cardtxdb \
  --db-user postgres \
  --db-password <password> \
  --add-customer
```

The script will automatically generate the next sequential account number (e.g., if `ACC000010` exists, it will create `ACC000011`).

### Delete a Customer

Delete a customer and all their associated transactions. Useful for testing CDC delete record processing.

```bash
uv run generate_test_data.py \
  --db-host <rds-endpoint> \
  --db-name cardtxdb \
  --db-user postgres \
  --db-password <password> \
  --delete-customer ACC000001
```

This will:
- Delete all transactions associated with the customer's account number
- Delete the customer record
- Display confirmation messages for both operations

### Delete a Transaction

Delete a single transaction by transaction ID. Useful for testing CDC delete record processing for transactions.

```bash
uv run generate_test_data.py \
  --db-host <rds-endpoint> \
  --db-name cardtxdb \
  --db-user postgres \
  --db-password <password> \
  --delete-transaction <transaction-uuid>
```

The transaction ID is a UUID that can be found in the transactions table or in the Kafka messages from Debezium.

## Options

| Option | Description | Default |
|-------|-------------|---------|
| `--db-host` | Database hostname | (required) |
| `--db-port` | Database port | 5432 |
| `--db-name` | Database name | cardtxdb |
| `--db-user` | Database user | postgres |
| `--db-password` | Database password | (required) |
| `--run-forever` | Run in continuous mode | False |
| `--interval` | Seconds between transaction batches (continuous mode) | 5 |
| `--num-customers` | Number of customers (one-shot mode) | 10 |
| `--num-transactions` | Number of transactions (one-shot mode) | 10 |
| `--add-customer` | Add a single customer to the database | False |
| `--delete-customer` | Delete a customer by account number (e.g., ACC000001) | None |
| `--delete-transaction` | Delete a transaction by transaction ID (UUID) | None |

## Generated Data

### Customers
- Account numbers: `ACC000001`, `ACC000002`, etc.
- Realistic names, emails, phone numbers
- Random cities from major US cities
- Random birth dates (18-80 years old)

### Transactions
- UUID transaction IDs
- Amounts: $1-$500 (with 5% chance of $1000-$5000)
- Random merchants (Amazon, Walmart, Starbucks, etc.)
- Random transaction types: PURCHASE, ONLINE, ATM, REFUND, FEE
- Random statuses: PENDING, COMPLETED, FAILED, CANCELLED
- Timestamps within last 7 days (or current time in continuous mode)

## Example Output

### One-Shot Mode
```
🔌 Connecting to database: postgres@card-tx-db-xxxxx.xxxxx.us-east-2.rds.amazonaws.com:5432/cardtxdb
✓ Connected to database

📊 Generating initial test data...
   Customers: 10
   Transactions: 10

✓ Inserted/updated 10 customers
✓ Inserted 10 transactions

✅ Initial data generation complete!
   Total customers: 10
   Total transactions: 10

✓ Database connection closed
```

### Continuous Mode
```
🔌 Connecting to database: postgres@card-tx-db-xxxxx.xxxxx.us-east-2.rds.amazonaws.com:5432/cardtxdb
✓ Connected to database

🔄 Starting continuous transaction generation...
   Interval: 5 seconds
   Press Ctrl+C to stop

   Using 10 existing customers

   [2024-01-15 10:30:15] Generated 2 transaction(s) (Total: 2)
   [2024-01-15 10:30:20] Generated 1 transaction(s) (Total: 3)
   [2024-01-15 10:30:25] Generated 3 transaction(s) (Total: 6)
   ...
```

### Add Customer Mode
```
🔌 Connecting to database: postgres@card-tx-db-xxxxx.xxxxx.us-east-2.rds.amazonaws.com:5432/cardtxdb
✓ Connected to database

✓ Added customer: ACC000011 - Alice Smith

✓ Database connection closed
```

### Delete Customer Mode
```
🔌 Connecting to database: postgres@card-tx-db-xxxxx.xxxxx.us-east-2.rds.amazonaws.com:5432/cardtxdb
✓ Connected to database

✓ Deleted customer: ACC000001 - Bob Johnson
✓ Deleted 5 transaction(s) for this customer

✓ Database connection closed
```

### Delete Transaction Mode
```
🔌 Connecting to database: postgres@card-tx-db-xxxxx.xxxxx.us-east-2.rds.amazonaws.com:5432/cardtxdb
✓ Connected to database

✓ Deleted transaction: 550e8400-e29b-41d4-a716-446655440000
   Account: ACC000001, Amount: $125.50, Merchant: Amazon

✓ Database connection closed
```

## Notes

- The script uses `ON CONFLICT` clauses to handle duplicate inserts gracefully
- In continuous mode, transactions are generated with current timestamps
- The script will create customers automatically if none exist in continuous mode
- Press `Ctrl+C` to stop continuous generation
