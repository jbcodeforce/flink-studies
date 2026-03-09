#!/usr/bin/env python3
"""
Create and populate the loan_applications table in PostgreSQL.
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


def create_loan_applications_table(cur, conn):
    """Create the loan_applications table if it doesn't exist"""
    cur.execute("""
        CREATE TABLE IF NOT EXISTS loan_applications (
            application_id VARCHAR(255) PRIMARY KEY,
            customer_id VARCHAR(255),
            application_date DATE,
            loan_type VARCHAR(255),
            loan_amount_requested FLOAT,
            loan_tenure_months INT,
            interest_rate_offered FLOAT,
            purpose_of_loan VARCHAR(255),
            employment_status VARCHAR(255),
            monthly_income FLOAT,
            cibil_score INT,
            existing_emis_monthly FLOAT,
            debt_to_income_ratio FLOAT,
            property_ownership_status VARCHAR(255),
            residential_address VARCHAR(255),
            applicant_age INT,
            gender VARCHAR(255),
            number_of_dependents INT,
            loan_status VARCHAR(255),
            fraud_flag BOOLEAN,
            fraud_type VARCHAR(255)
        )
    """)
    conn.commit()
    print("Table loan_applications created successfully")


def insert_loan_applications(cur, conn, use_small: bool = False):
    """Insert loan applications data from CSV file"""
    sql = """
        INSERT INTO loan_applications (
            application_id, customer_id, application_date, loan_type,
            loan_amount_requested, loan_tenure_months, interest_rate_offered,
            purpose_of_loan, employment_status, monthly_income, cibil_score,
            existing_emis_monthly, debt_to_income_ratio, property_ownership_status,
            residential_address, applicant_age, gender, number_of_dependents,
            loan_status, fraud_flag, fraud_type
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        ON CONFLICT (application_id) DO NOTHING
    """
    
    filename = "loan_applications_small.csv" if use_small else "loan_applications.csv"
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
    print(f"Inserted {count} records into loan_applications table")


def main():
    parser = argparse.ArgumentParser(description="Load loan applications data into PostgreSQL")
    parser.add_argument("--small", action="store_true", help="Use small dataset (15 records)")
    parser.add_argument("--config", default=os.path.join(SCRIPT_DIR, "local_db.ini"),
                        help="Path to database config file")
    args = parser.parse_args()
    
    cur, conn = connect(args.config)
    try:
        create_loan_applications_table(cur, conn)
        insert_loan_applications(cur, conn, use_small=args.small)
    finally:
        cur.close()
        conn.close()
        print("Database connection closed")


if __name__ == '__main__':
    main()
