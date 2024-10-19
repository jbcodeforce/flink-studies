import json
import random
import time
from datetime import datetime
from confluent_kafka import Producer
import os

KAFKA_BROKERS = os.getenv('KAFKA_BOOTSTRAP_SERVERS','localhost:9092')
KAFKA_CERT = os.getenv('KAFKA_CERT','')
KAFKA_USER =  os.getenv('KAFKA_USER','')
KAFKA_PASSWORD =  os.getenv('KAFKA_PASSWORD','')
KAFKA_SASL_MECHANISM=  os.getenv('KAFKA_SASL_MECHANISM','SCRAM-SHA-512')
TOPIC_NAME=os.getenv("KAFKA_MAIN_TOPIC","ecommerce_events")


# Sample data
USERS = ['user1', 'user2', 'user3', 'user4', 'user5']
PRODUCTS = ['laptop', 'smartphone', 'tablet', 'headphones', 'smartwatch']
PAGES = ['home', 'category', 'product', 'cart', 'checkout']

def generate_user_action():
    return {
        'event_type': 'user_action',
        'timestamp': datetime.now().isoformat(),
        'user_id': random.choice(USERS),
        'action': random.choice(['page_view', 'product_click', 'add_to_cart']),
        'page': random.choice(PAGES),
        'product': random.choice(PRODUCTS)
    }

def generate_purchase():
    return {
        'event_type': 'purchase',
        'timestamp': datetime.now().isoformat(),
        'user_id': random.choice(USERS),
        'product': random.choice(PRODUCTS),
        'quantity': random.randint(1, 5),
        'price': round(random.uniform(10, 1000), 2)
    }

def generate_inventory_update():
    return {
        'event_type': 'inventory_update',
        'timestamp': datetime.now().isoformat(),
        'product': random.choice(PRODUCTS),
        'quantity': random.randint(-10, 50)
    }

def generate_event():
    event_types = [generate_user_action, generate_purchase, generate_inventory_update]
    weights = [0.7, 0.2, 0.1]  # 70% user actions, 20% purchases, 10% inventory updates
    return random.choices(event_types, weights=weights)[0]()

def json_serializer(data):
    return json.dumps(data).encode('utf-8')

def create_kafka_producer():
    options ={
        'bootstrap.servers':  KAFKA_BROKERS,
        'delivery.timeout.ms': 15000,
        'request.timeout.ms' : 15000
        }
    print("kafka-user: " + KAFKA_USER)
    if (KAFKA_USER != ''):
        # options['security.protocol'] = 'SASL_SSL'
        options['security.protocol'] = 'PLAINTEXT'
        options['sasl.mechanisms'] = KAFKA_SASL_MECHANISM
        options['sasl.username'] = KAFKA_USER
        options['sasl.password'] = KAFKA_PASSWORD

    if (KAFKA_CERT != '' ):
        options['ssl.ca.location'] = KAFKA_CERT

    print("--- This is the configuration for the producer: ---")
    print('[KafkaProducer] - {}'.format(options))
    print("---------------------------------------------------")
    return Producer(options)
        

def main():
    producer = create_kafka_producer()
    try:
        while True:
            event = generate_event()
            print(event)
            if event['event_type'] == 'inventory_update':
                key=event['product']
            else:
                key=event['user_id']
            producer.produce(TOPIC_NAME, key=key, value= json.dumps(event))
            print(f"Sent event: {event}")
            time.sleep(random.uniform(0.1, 2))  # Random delay between 0.1 and 2 seconds
    except KeyboardInterrupt:
        print("Stopping data generation...")


if __name__ == "__main__":
    main()