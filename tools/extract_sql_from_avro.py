import requests
import json

"""
Build a SQL statment to create table from a schema subject in Confluent registry
"""
SUBJECT="shoe_products"
VERSION="1"



def map_schema_to_sql(subject: str, version: str) -> str:
    URL=f"http://localhost:8081/subjects/{subject}-value/versions/{version}"
    response = requests.get(URL)
    print(response.json())
    json_schema= response.json()["schema"]
    fields = json.loads(json_schema)["fields"]
    sql_str=f"CREATE TABLE {subject} (\n"
    sql_attributes=""
    key_name="id"
    for idx,f in enumerate(fields):
        name= f["name"]
        if idx == 0:
            key_name=name
        if type(f["type"]) != dict:
            col_type=f["type"].upper()
        else:
            # 
            print(type)
            col_type="TIMESTAMP_LTZ(3) METADATA FROM 'timestamp'"
        sql_attributes+="   "+ name + " " + col_type + ",\n"
    sql_str+=sql_attributes[:-2]
    sql_str+="\n) WITH (\n"
    sql_str+="  'connector' = 'kafka',\n"
    sql_str+=f"   'topic' = '{subject}',\n"
    sql_str+="   'properties.bootstrap.servers' = 'broker:29092',\n"
    sql_str+="   'scan.startup.mode' = 'earliest-offset',\n"
    sql_str+="   'key.format' = 'raw',\n"
    sql_str+=f"   'key.fields' = '{key_name}',\n"
    sql_str+="   'value.format' = 'avro-confluent',\n"
    sql_str+="   'properties.group.id' = 'flink-sql-consumer',\n"
    sql_str+="   'value.fields-include' = 'ALL',\n"
    sql_str+="   'value.avro-confluent.url' = 'http://schema-registry:8081'\n);\n"
    return sql_str

def extract_save_to_file(subject: str, version: str): 
    sql_statment=map_schema_to_sql(subject,version)
    print(sql_statment)
    with open(subject+".sql","w") as f:
        f.write(sql_statment)
        f.close()


extract_save_to_file("shoe_products","1")
extract_save_to_file("shoe_customers","1")
extract_save_to_file("shoe_orders","1")
