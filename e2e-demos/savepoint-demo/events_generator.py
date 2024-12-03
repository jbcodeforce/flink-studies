"""
The goal of this script is to be able to send different event types to the 
topics configured in the config.yaml file, and the event structure from event_definitions

This is a source to test the Flink processing with controlled scenarios. 
"""
from app_config import read_config
import datetime
import sys
from event_definitions import order_record
from confluent_kafka import  SerializingProducer
from confluent_kafka.schema_registry.avro import AvroSerializer
from confluent_kafka.schema_registry import SchemaRegistryClient

def delivery_report(err, msg):
    """
    Reports the failure or success of a message delivery.

    Args:
        err (KafkaError): The error that occurred on None on success.

        msg (Message): The message that was produced or failed.

    Note:
        In the delivery report callback the Message.key() and Message.value()
        will be the binary format as encoded by any configured Serializers and
        not the same object that was passed to produce().
        If you wish to pass the original object(s) for key and value to delivery
        report callback we recommend a bound callback or lambda where you pass
        the objects along.
    """

    if err is not None:
        print("Delivery failed for User record {}: {}".format(msg.key(), err))
        return
    print('User record {} successfully produced to {} [{}] at offset {}'.format(
        msg.key(), msg.topic(), msg.partition(), msg.offset()))
    
def avro_produce(topic, config, event_key:str, event_value, registry_client: SchemaRegistryClient, subject: str):
  schema_str = registry_client.get_latest_version(subject).schema.schema_str
  avro_serializer = AvroSerializer(registry_client, schema_str, conf= {"auto.register.schemas": True })
  config["value.serializer"]=avro_serializer
  producer = SerializingProducer(config)
  producer.produce(topic, 
                   key=event_key, 
                   value=event_value,
                   on_delivery=delivery_report)
  print(f"Produced message to topic {topic}: key = {event_key:12} value = {event_value}")
  producer.flush()

def generate_order_records(config, nb_events: int):
    """
    Generate the records to the target topic
    """
    registry_url=config["registry"]["url"]
    if "localhost" in registry_url:
        sr_client= SchemaRegistryClient({"url": registry_url})
    else:
        sr_client= SchemaRegistryClient({"url": registry_url, 
                                     "basic.auth.user.info":  config["registry"]["registry_key_name"]
                                                        + ":" + config["registry"]["registry_key_secret"]})
    topic=config["app"]["topics"]["order_topic"]
    for i in range(0,nb_events):
        resr = order_record(id=f"order_00{i}",
                                        ts_ms= datetime.datetime.now(),
                                        )
        avro_produce(topic, 
                  config["kafka"], 
                  resr.id, 
                  resr.model_dump(),
                  sr_client,
                  topic + "-value"
                  )
    # generate a duplicate
    resr = order_record(id=f"order_002",            
                        ts_ms= datetime.datetime.now(),
                        )
    avro_produce(topic, 
                  config["kafka"], 
                  resr.id, 
                  resr.model_dump(),
                  sr_client,
                  topic + "-value"
                  )

if __name__ == "__main__":
    print("Starting event generation")
    if len(sys.argv) > 0:
        nb_events: int = int(sys.argv[1])
    else:
        nb_events = 10
    config = read_config()
    generate_order_records(config, nb_events)