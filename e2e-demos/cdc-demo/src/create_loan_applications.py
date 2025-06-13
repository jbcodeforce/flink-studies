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

def create_loan_applications_table(cur, conn):
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

def insert_loan_applications(cur, conn):
    sql="""
        INSERT INTO loan_applications (application_id, customer_id, application_date, loan_type, loan_amount_requested, loan_tenure_months, interest_rate_offered, purpose_of_loan, employment_status, monthly_income, cibil_score, existing_emis_monthly, debt_to_income_ratio, property_ownership_status, residential_address, applicant_age, gender, number_of_dependents, loan_status, fraud_flag, fraud_type)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
    """
    with open("../datasets/loan_applications.csv", "r") as file:
        reader = csv.reader(file)
        next(reader) # Skip header row
        for row in reader:
            cur.execute(sql, row)
    conn.commit()
    print("Data inserted into loan_applications table successfully")

if __name__ == '__main__':
    cur, conn = connect("local_db.ini")
    create_loan_applications_table(cur, conn)
    insert_loan_applications(cur, conn)
