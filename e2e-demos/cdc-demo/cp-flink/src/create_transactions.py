#!/usr/bin/env python3
"""
Create and populate the transactions table in PostgreSQL.
Supports --small flag to use a smaller dataset for demos.
"""
import argparse
import csv
import os
import psycopg2
from config import config

# Get the directory where this script is located
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(SCRIPT_DIR)


def connect(db_cfg_name: str):
    """Connect to the PostgreSQL database server"""
    try:
        params = config(filename=db_cfg_name)
        conn = psycopg2.connect(**params)
        cur = conn.cursor()
        print("Connected to the PostgreSQL database")
        return cur, conn
    except (Exception, psycopg2.DatabaseError) as error:
        print(f"Connection error: {error}")
        raise error


def create_transactions_table(cur, conn):
    """Create the transactions table if it doesn't exist"""
    cur.execute("""
        CREATE TABLE IF NOT EXISTS transactions (
            transaction_id VARCHAR(255) PRIMARY KEY,
            customer_id VARCHAR(255),
            transaction_date TIMESTAMP,
            transaction_type VARCHAR(255),
            transaction_amount FLOAT,
            merchant_category VARCHAR(255),
            merchant_name VARCHAR(255),
            transaction_location VARCHAR(255),
            account_balance_after_transaction FLOAT,
            is_international_transaction BOOLEAN,
            device_used VARCHAR(255),
            ip_address VARCHAR(255),
            transaction_status VARCHAR(255),
            transaction_source_destination VARCHAR(255),
            transaction_notes TEXT,
            fraud_flag BOOLEAN
        )
    """)
    conn.commit()
    print("Table transactions created successfully")


def insert_transactions(cur, conn, use_small: bool = False):
    """Insert transactions data from CSV file"""
    sql = """
        INSERT INTO transactions (
            transaction_id, customer_id, transaction_date, transaction_type,
            transaction_amount, merchant_category, merchant_name, transaction_location,
            account_balance_after_transaction, is_international_transaction,
            device_used, ip_address, transaction_status, transaction_source_destination,
            transaction_notes, fraud_flag
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        ON CONFLICT (transaction_id) DO NOTHING
    """
    
    filename = "transactions_small.csv" if use_small else "transactions.csv"
    filepath = os.path.join(PROJECT_DIR, "datasets", filename)
    
    if not os.path.exists(filepath):
        print(f"Error: File not found: {filepath}")
        return
    
    count = 0
    with open(filepath, "r") as file:
        reader = csv.reader(file)
        next(reader)  # Skip header row
        for row in reader:
            # Convert empty strings to None for proper NULL handling
            row = [None if val == '' else val for val in row]
            cur.execute(sql, row)
            count += 1
    
    conn.commit()
    print(f"Inserted {count} records into transactions table")


def main():
    parser = argparse.ArgumentParser(description="Load transactions data into PostgreSQL")
    parser.add_argument("--small", action="store_true", help="Use small dataset (15 records)")
    parser.add_argument("--config", default=os.path.join(SCRIPT_DIR, "local_db.ini"),
                        help="Path to database config file")
    args = parser.parse_args()
    
    cur, conn = connect(args.config)
    try:
        create_transactions_table(cur, conn)
        insert_transactions(cur, conn, use_small=args.small)
    finally:
        cur.close()
        conn.close()
        print("Database connection closed")


if __name__ == '__main__':
    main()
