import csv
import psycopg2
from config import config

def connect(db_cfg_name: str):
    """ Connect to the PostgreSQL database server """
    conn = None
    try:
        params = config(filename=db_cfg_name)
        conn = psycopg2.connect(**params)
        cur = conn.cursor()
        print("Connected to the PostgreSQL database")
        return cur, conn
    except (Exception, psycopg2.DatabaseError) as error:
        print(error)
        raise error


def create_transactions_table(cur, conn):
    cur.execute("""
       CREATE TABLE IF NOT EXISTS transactions (
            transaction_id VARCHAR(255) PRIMARY KEY,
            customer_id VARCHAR(255),
            transaction_date DATE,
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

def insert_transactions(cur, conn):
    sql="""
        INSERT INTO transactions (transaction_id, customer_id, transaction_date, transaction_type, transaction_amount, merchant_category, merchant_name, transaction_location, account_balance_after_transaction, is_international_transaction, device_used, ip_address, transaction_status, transaction_source_destination, transaction_notes, fraud_flag)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
    """
    with open("./datasets/transactions.csv", "r") as file:
        reader = csv.reader(file)
        next(reader) # Skip header row
        for row in reader:
            cur.execute(sql, row)
    conn.commit()
    print("Data inserted into transactions table successfully")

if __name__ == '__main__':
    cur, conn = connect("src/local_db.ini")
    create_transactions_table(cur, conn)
    insert_transactions(cur, conn)
