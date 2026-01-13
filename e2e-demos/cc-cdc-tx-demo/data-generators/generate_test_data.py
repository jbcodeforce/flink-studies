#!/usr/bin/env python3
"""
Test Data Generator for Card Transaction Demo

Generates sample customers and transactions for testing the CDC pipeline.
Can run in one-shot mode (10 customers + 10 transactions) or continuous mode.

Usage:
    # One-shot: Generate 10 customers and 10 transactions
    uv run generate_test_data.py --db-host <host> --db-name cardtxdb --db-user postgres --db-password <pass>

    # Continuous: Generate transactions forever
    uv run generate_test_data.py --db-host <host> --db-name cardtxdb --db-user postgres --db-password <pass> --run-forever

    # Add a single customer
    uv run generate_test_data.py --db-host <host> --db-name cardtxdb --db-user postgres --db-password <pass> --add-customer

    # Delete a customer by account number
    uv run generate_test_data.py --db-host <host> --db-name cardtxdb --db-user postgres --db-password <pass> --delete-customer ACC000001

    # With environment variables
    export DB_HOST=<host>
    export DB_NAME=cardtxdb
    export DB_USER=postgres
    export DB_PASSWORD=<pass>
    uv run generate_test_data.py --run-forever
"""

import argparse
import os
import random
import sys
import time
import uuid
from datetime import datetime, timedelta
from typing import List, Tuple

try:
    import psycopg2
    from psycopg2.extras import execute_values
except ImportError:
    print("Error: psycopg2 is required. Install with: pip install psycopg2-binary")
    sys.exit(1)


# Sample data pools
CITIES = [
    "New York", "Los Angeles", "Chicago", "Houston", "Phoenix",
    "Philadelphia", "San Antonio", "San Diego", "Dallas", "San Jose",
    "Austin", "Jacksonville", "San Francisco", "Columbus", "Fort Worth"
]

FIRST_NAMES = [
    "Alice", "Bob", "Charlie", "Diana", "Eve", "Frank", "Grace", "Henry",
    "Ivy", "Jack", "Karen", "Liam", "Mia", "Noah", "Olivia", "Paul",
    "Quinn", "Rachel", "Sam", "Tina", "Uma", "Victor", "Wendy", "Xavier"
]

LAST_NAMES = [
    "Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller",
    "Davis", "Rodriguez", "Martinez", "Hernandez", "Lopez", "Wilson",
    "Anderson", "Thomas", "Taylor", "Moore", "Jackson", "Martin"
]

MERCHANTS = [
    "Amazon", "Walmart", "Target", "Best Buy", "Home Depot",
    "Starbucks", "McDonald's", "Subway", "CVS Pharmacy", "Walgreens",
    "Costco", "Whole Foods", "Trader Joe's", "Apple Store", "Nike",
    "Macy's", "Nordstrom", "Gap", "Old Navy", "Zara"
]

TRANSACTION_TYPES = ["PURCHASE", "ONLINE", "ATM", "REFUND", "FEE"]
STATUSES = ["PENDING", "COMPLETED", "FAILED", "CANCELLED"]
CURRENCIES = ["USD", "EUR", "GBP"]


def generate_customer(account_number: str) -> Tuple:
    """Generate a single customer record."""
    first_name = random.choice(FIRST_NAMES)
    last_name = random.choice(LAST_NAMES)
    customer_name = f"{first_name} {last_name}"
    email = f"{first_name.lower()}.{last_name.lower()}@example.com"
    phone_number = f"+1-{random.randint(200, 999)}-{random.randint(200, 999)}-{random.randint(1000, 9999)}"
    
    # Date of birth between 18 and 80 years ago
    years_ago = random.randint(18, 80)
    date_of_birth = datetime.now() - timedelta(days=years_ago * 365 + random.randint(0, 365))
    
    city = random.choice(CITIES)
    created_at = datetime.now() - timedelta(days=random.randint(0, 365))
    
    return (
        account_number,
        customer_name,
        email,
        phone_number,
        date_of_birth,
        city,
        created_at
    )


def generate_transaction(account_number: str, txn_id: str = None) -> Tuple:
    """Generate a single transaction record."""
    if txn_id is None:
        txn_id = str(uuid.uuid4())
    
    # Amount between $1 and $5000, with some high-value outliers
    if random.random() < 0.05:  # 5% chance of high-value transaction
        amount = round(random.uniform(1000, 5000), 2)
    else:
        amount = round(random.uniform(1, 500), 2)
    
    currency = random.choice(CURRENCIES)
    merchant = random.choice(MERCHANTS)
    location = random.choice(CITIES)
    status = random.choice(STATUSES)
    transaction_type = random.choice(TRANSACTION_TYPES)
    
    # Timestamp within last 7 days, or now for continuous mode
    timestamp = datetime.now() - timedelta(
        days=random.randint(0, 7),
        hours=random.randint(0, 23),
        minutes=random.randint(0, 59)
    )
    
    return (
        txn_id,
        account_number,
        timestamp,
        amount,
        currency,
        merchant,
        location,
        status,
        transaction_type
    )


def insert_customers(conn, customers: List[Tuple]) -> None:
    """Insert customers into the database."""
    cursor = conn.cursor()
    
    insert_query = """
        INSERT INTO customers (
            account_number, customer_name, email, phone_number,
            date_of_birth, city, created_at
        ) VALUES %s
        ON CONFLICT (account_number) DO UPDATE SET
            customer_name = EXCLUDED.customer_name,
            email = EXCLUDED.email,
            phone_number = EXCLUDED.phone_number,
            city = EXCLUDED.city
    """
    
    execute_values(cursor, insert_query, customers)
    conn.commit()
    cursor.close()
    print(f"✓ Inserted/updated {len(customers)} customers")


def insert_transactions(conn, transactions: List[Tuple]) -> None:
    """Insert transactions into the database."""
    cursor = conn.cursor()
    
    insert_query = """
        INSERT INTO transactions (
            txn_id, account_number, timestamp, amount, currency,
            merchant, location, status, transaction_type
        ) VALUES %s
        ON CONFLICT (txn_id) DO NOTHING
    """
    
    execute_values(cursor, insert_query, transactions)
    conn.commit()
    cursor.close()
    print(f"✓ Inserted {len(transactions)} transactions")


def add_customer(conn, account_number: str = None) -> str:
    """
    Add a single customer to the database.
    
    Args:
        conn: Database connection
        account_number: Optional account number. If not provided, generates a random one.
    
    Returns:
        The account_number of the added customer
    """
    cursor = conn.cursor()
    
    # Generate account number if not provided
    if account_number is None:
        # Find the highest existing account number to generate next sequential one
        cursor.execute("SELECT MAX(account_number) FROM customers WHERE account_number LIKE 'ACC%'")
        result = cursor.fetchone()
        if result[0]:
            # Extract number from existing account (e.g., "ACC000010" -> 10)
            try:
                max_num = int(result[0][3:])
                account_number = f"ACC{str(max_num + 1).zfill(6)}"
            except (ValueError, IndexError):
                account_number = f"ACC{str(random.randint(1, 999999)).zfill(6)}"
        else:
            account_number = f"ACC{str(random.randint(1, 999999)).zfill(6)}"
    
    # Generate customer data
    customer = generate_customer(account_number)
    
    # Insert customer
    insert_query = """
        INSERT INTO customers (
            account_number, customer_name, email, phone_number,
            date_of_birth, city, created_at
        ) VALUES (%s, %s, %s, %s, %s, %s, %s)
        ON CONFLICT (account_number) DO UPDATE SET
            customer_name = EXCLUDED.customer_name,
            email = EXCLUDED.email,
            phone_number = EXCLUDED.phone_number,
            city = EXCLUDED.city
    """
    
    cursor.execute(insert_query, customer)
    conn.commit()
    cursor.close()
    
    print(f"✓ Added customer: {account_number} - {customer[1]}")
    return account_number


def delete_customer(conn, account_number: str) -> bool:
    """
    Delete a customer and all their transactions from the database by account number.
    
    Args:
        conn: Database connection
        account_number: Account number of the customer to delete
    
    Returns:
        True if customer was deleted, False if not found
    """
    cursor = conn.cursor()
    
    # First check if customer exists
    cursor.execute("SELECT customer_name FROM customers WHERE account_number = %s", (account_number,))
    result = cursor.fetchone()
    
    if not result:
        cursor.close()
        print(f"⚠️  Customer not found: {account_number}")
        return False
    
    customer_name = result[0]
    
    # Delete all transactions for this customer first
    cursor.execute("DELETE FROM transactions WHERE account_number = %s", (account_number,))
    transactions_deleted = cursor.rowcount
    
    # Delete the customer
    cursor.execute("DELETE FROM customers WHERE account_number = %s", (account_number,))
    rows_deleted = cursor.rowcount
    conn.commit()
    cursor.close()
    
    if rows_deleted > 0:
        print(f"✓ Deleted customer: {account_number} - {customer_name}")
        if transactions_deleted > 0:
            print(f"✓ Deleted {transactions_deleted} transaction(s) for this customer")
        return True
    else:
        print(f"⚠️  Failed to delete customer: {account_number}")
        return False


def generate_initial_data(conn, num_customers: int = 10, num_transactions: int = 10) -> None:
    """Generate initial test data (customers and transactions)."""
    print(f"\n📊 Generating initial test data...")
    print(f"   Customers: {num_customers}")
    print(f"   Transactions: {num_transactions}\n")
    
    # Generate customers
    customers = []
    account_numbers = []
    
    for i in range(num_customers):
        account_number = f"ACC{str(i+1).zfill(6)}"
        account_numbers.append(account_number)
        customers.append(generate_customer(account_number))
    
    insert_customers(conn, customers)
    
    # Generate transactions
    transactions = []
    for i in range(num_transactions):
        account_number = random.choice(account_numbers)
        transactions.append(generate_transaction(account_number))
    
    insert_transactions(conn, transactions)
    
    print(f"\n✅ Initial data generation complete!")
    print(f"   Total customers: {num_customers}")
    print(f"   Total transactions: {num_transactions}\n")


def generate_continuous_transactions(conn, interval_seconds: int = 5) -> None:
    """Generate transactions continuously in a loop."""
    print(f"\n🔄 Starting continuous transaction generation...")
    print(f"   Interval: {interval_seconds} seconds")
    print(f"   Press Ctrl+C to stop\n")
    
    # Get existing account numbers
    cursor = conn.cursor()
    cursor.execute("SELECT account_number FROM customers LIMIT 100")
    account_numbers = [row[0] for row in cursor.fetchall()]
    cursor.close()
    
    if not account_numbers:
        print("⚠️  No customers found! Generating 10 customers first...")
        generate_initial_data(conn, num_customers=10, num_transactions=0)
        cursor = conn.cursor()
        cursor.execute("SELECT account_number FROM customers")
        account_numbers = [row[0] for row in cursor.fetchall()]
        cursor.close()
    
    print(f"   Using {len(account_numbers)} existing customers\n")
    
    transaction_count = 0
    
    try:
        while True:
            # Generate 1-3 transactions per interval
            num_txns = random.randint(1, 3)
            transactions = []
            
            for _ in range(num_txns):
                account_number = random.choice(account_numbers)
                transactions.append(generate_transaction(account_number))
            
            insert_transactions(conn, transactions)
            transaction_count += len(transactions)
            
            print(f"   [{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] "
                  f"Generated {len(transactions)} transaction(s) "
                  f"(Total: {transaction_count})")
            
            time.sleep(interval_seconds)
            
    except KeyboardInterrupt:
        print(f"\n\n🛑 Stopped continuous generation")
        print(f"   Total transactions generated: {transaction_count}\n")


def get_db_connection(host: str, port: int, database: str, user: str, password: str):
    """Create and return a database connection."""
    try:
        conn = psycopg2.connect(
            host=host,
            port=port,
            database=database,
            user=user,
            password=password,
            connect_timeout=10
        )
        return conn
    except psycopg2.Error as e:
        print(f"❌ Error connecting to database: {e}")
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(
        description="Generate test data for Card Transaction Demo",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    
    # Database connection arguments
    parser.add_argument(
        "--db-host",
        default=os.getenv("DB_HOST"),
        help="Database host (or set DB_HOST env var)"
    )
    parser.add_argument(
        "--db-port",
        type=int,
        default=int(os.getenv("DB_PORT", "5432")),
        help="Database port (default: 5432, or set DB_PORT env var)"
    )
    parser.add_argument(
        "--db-name",
        default=os.getenv("DB_NAME", "cardtxdb"),
        help="Database name (default: cardtxdb, or set DB_NAME env var)"
    )
    parser.add_argument(
        "--db-user",
        default=os.getenv("DB_USER", "postgres"),
        help="Database user (default: postgres, or set DB_USER env var)"
    )
    parser.add_argument(
        "--db-password",
        default=os.getenv("DB_PASSWORD"),
        help="Database password (or set DB_PASSWORD env var)"
    )
    
    # Generation options
    parser.add_argument(
        "--run-forever",
        action="store_true",
        help="Run in continuous mode, generating transactions forever"
    )
    parser.add_argument(
        "--interval",
        type=int,
        default=5,
        help="Interval in seconds between transaction batches (default: 5)"
    )
    parser.add_argument(
        "--num-customers",
        type=int,
        default=10,
        help="Number of customers to generate in one-shot mode (default: 10)"
    )
    parser.add_argument(
        "--num-transactions",
        type=int,
        default=10,
        help="Number of transactions to generate in one-shot mode (default: 10)"
    )
    parser.add_argument(
        "--add-customer",
        action="store_true",
        help="Add a single customer to the database"
    )
    parser.add_argument(
        "--delete-customer",
        type=str,
        metavar="ACCOUNT_NUMBER",
        help="Delete a customer by account number (e.g., ACC000001)"
    )
    
    args = parser.parse_args()
    
    # Validate required arguments
    if not args.db_host:
        parser.error("--db-host is required (or set DB_HOST environment variable)")
    if not args.db_password:
        parser.error("--db-password is required (or set DB_PASSWORD environment variable)")
    
    # Connect to database
    print(f"🔌 Connecting to database: {args.db_user}@{args.db_host}:{args.db_port}/{args.db_name}")
    conn = get_db_connection(
        host=args.db_host,
        port=args.db_port,
        database=args.db_name,
        user=args.db_user,
        password=args.db_password
    )
    print("✓ Connected to database\n")
    
    try:
        if args.add_customer:
            add_customer(conn)
        elif args.delete_customer:
            delete_customer(conn, args.delete_customer)
        elif args.run_forever:
            generate_continuous_transactions(conn, interval_seconds=args.interval)
        else:
            generate_initial_data(
                conn,
                num_customers=args.num_customers,
                num_transactions=args.num_transactions
            )
    finally:
        conn.close()
        print("✓ Database connection closed")


if __name__ == "__main__":
    main()
