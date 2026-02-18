import psycopg2


CREATE_USERS_TABLE = """
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
"""

INSERT_USERS = """
INSERT INTO users (name, email) VALUES
    ('Alice Johnson', 'alice@example.com'),
    ('Bob Smith', 'bob@example.com'),
    ('Carol Williams', 'carol@example.com'),
    ('David Brown', 'david@example.com'),
    ('Eve Davis', 'eve@example.com'),
    ('Frank Miller', 'frank@example.com'),
    ('Grace Wilson', 'grace@example.com'),
    ('Henry Moore', 'henry@example.com'),
    ('Ivy Taylor', 'ivy@example.com'),
    ('Jack Anderson', 'jack@example.com')
ON CONFLICT (email) DO NOTHING;
"""

def connect_to_rds(password):
    conn = psycopg2.connect(
        host='j9r-pgdb.cndsjke6xo5r.us-west-2.rds.amazonaws.com',
        port=5432,
        database='postgres',
        user='postgres',
        password=password
    )
    return conn

def create_users_table(conn):
    cur = conn.cursor()
    cur.execute(CREATE_USERS_TABLE)
    conn.commit()
    print('Table "users" created or already exists.')

def insert_users(conn):
    cur = conn.cursor()
    cur.execute(INSERT_USERS)
    conn.commit()
    print('Inserted 10 user records.')

def select_users(conn):
    cur = conn.cursor()
    cur.execute('SELECT id, name, email FROM users ORDER BY id;')
    for row in cur.fetchall():
        print(f'  {row[0]}: {row[1]} <{row[2]}>')

def close_connection(conn):
    if conn:
        conn.close()

def main():
    print('Enter user password:')
    password = input()
    conn = connect_to_rds(password)
    #create_users_table(conn)
    #insert_users(conn)
    select_users(conn)
    close_connection(conn)

if __name__ == '__main__':
    main()
