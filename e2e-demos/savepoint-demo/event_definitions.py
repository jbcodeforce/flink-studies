
from typing import Optional, get_type_hints
from pydantic_avro.base import AvroBase
from datetime import datetime
import json
from confluent_kafka.schema_registry import SchemaRegistryClient, Schema
from confluent_kafka.schema_registry.avro import AvroSerializer
from app_config import read_config

SQLS_PATH="../flink_sqls/tmp"

class order_record(AvroBase):
        id: str
        ts_ms: datetime
        value: int = 2



def define_schemas(config, klass, name):
  registry_url=config["registry"]["url"]
  if "localhost" in registry_url:
      sr_client= SchemaRegistryClient({"url": registry_url})
  else:
    sr_client= SchemaRegistryClient({"url": config["registry"]["url"], 
                                   "basic.auth.user.info":  config["registry"]["registry_key_name"]+":"+config["registry"]["registry_key_secret"]})
  schema = json.dumps(klass.avro_schema())
  sc = Schema(schema_str=schema, schema_type="AVRO")
  schema_id=sr_client.register_schema(subject_name=name, schema=sc)
  print(f"Registered {klass} as {schema_id}")


def upload_schemas_to_registry(config):
  """ Important that the subject name for the schema has the nam of the topic + "-value" so
  it can be automatically associated to the topic
  """
  define_schemas(config, order_record,config["app"]["topics"]["order_topic"] + "-value")
  
def write_avro_file(klass, name):
  schema = json.dumps(klass.avro_schema())
  with open("./avro/" + name + ".avsc", "w") as f:
    f.write(schema)
  f.close()

# map from topic to type
known_model_classes = { "order_topic": order_record}

def generate_avros(config):
  for schema_name in config["app"]["topics"]:
    write_avro_file(known_model_classes[schema_name], config["app"]["topics"][schema_name] +  "-value")

def work_field(name,col_type):
    print(f" work_field {name}  {col_type}")
    if isinstance(col_type, list):
      if col_type[0] == "null":
        name,col_type=work_field(name,"string")
      else:
        name,col_type=work_field(name,col_type[0])
    elif isinstance(col_type, dict):
        name, col_type=work_field(name,col_type["type"])
    elif col_type == "long":
        col_type = "BIGINT"
    else:
       col_type=col_type.upper()
    return name, col_type
       
def generate_raw_sql(klass):
  #print(klass.__fields__)
  sql_str=f"CREATE TABLE {klass.__name__} (\n"
  sql_columns=""
  avro= klass.avro_schema()
  for field in avro["fields"]:
    name,col_type= work_field(field["name"], field["type"])
    sql_columns+=f"   `{name}`  {str(col_type)},\n"
    
  sql_str+=sql_columns[:-2]
  sql_str+="\n) WITH (\n"
  sql_str+="     'changelog.mode' = 'upsert',\n"
  sql_str+="     'scan.bounded.mode' = 'unbounded',\n"
  sql_str+="     'scan.startup.mode' = 'earliest-offset',\n"
  sql_str+="     'kafka.retention.time' = '0'\n"
  sql_str+=" \n);\n"
  return sql_str

if __name__ == "__main__":
  config = read_config()
  generate_avros(config)
  upload_schemas_to_registry(config)
  for t in config["app"]["topics"]:
    sql=generate_raw_sql(known_model_classes[t])
    print(sql)