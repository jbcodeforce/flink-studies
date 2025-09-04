#!/usr/bin/env python3
"""
Generic Kafka Producer to create json payload
"""

import json
import random
import time
import uuid

from typing import Optional, Dict, Any
from confluent_kafka import Producer
from pydantic import BaseModel, Field
import os
from models import generate_job_record, generate_order_record

# Kafka Configuration from Environment Variables
KAFKA_BROKERS = os.getenv('KAFKA_BOOTSTRAP_SERVERS', 'localhost:9094')
KAFKA_CERT = os.getenv('KAFKA_CERT', '')
KAFKA_USER = os.getenv('KAFKA_USER', '')
KAFKA_PASSWORD = os.getenv('KAFKA_PASSWORD', '')
KAFKA_SASL_MECHANISM = os.getenv('KAFKA_SASL_MECHANISM', 'PLAIN')
KAFKA_SECURITY_PROTOCOL = os.getenv('KAFKA_SECURITY_PROTOCOL', 'PLAINTEXT')
DEFAULT_TOPIC = os.getenv('KAFKA_TOPIC', 'raw-orders')


class KafkaJSONProducer:
    """Flexible Kafka JSON Producer"""
    
    def __init__(self, topic_name: str = DEFAULT_TOPIC):
        self.topic_name = topic_name
        self.producer = self._create_producer()
        
    def _create_producer(self) -> Producer:
        """Create and configure Kafka producer with environment-based settings"""
        options = {
            'bootstrap.servers': KAFKA_BROKERS,
            'delivery.timeout.ms': 15000,
            'request.timeout.ms': 15000,
            'client.id': f'producer-{uuid.uuid4().hex[:8]}'
        }
        
        print(f"Kafka User: {KAFKA_USER}")
        if KAFKA_USER:
            options.update({
                'security.protocol': KAFKA_SECURITY_PROTOCOL,
                'sasl.mechanisms': KAFKA_SASL_MECHANISM,
                'sasl.username': KAFKA_USER,
                'sasl.password': KAFKA_PASSWORD
            })

        if KAFKA_CERT:
            options['ssl.ca.location'] = KAFKA_CERT

        print("=== Kafka Producer Configuration ===")
        print(f"Bootstrap servers: {options['bootstrap.servers']}")
        print(f"Security protocol: {options.get('security.protocol', 'PLAINTEXT')}")
        print(f"Topic: {self.topic_name}")
        print("===================================")
        
        return Producer(options)
    
    def _delivery_report(self, err, msg):
        """Callback for message delivery reports"""
        if err is not None:
            print(f"❌ Message delivery failed: {err}")
        else:
            print(f"✅ Message delivered to {msg.topic()} [{msg.partition()}] offset {msg.offset()}")
    
    def send_record(self, record: BaseModel, key: Optional[str] = None) -> bool:
        """Send a Pydantic model as JSON to Kafka"""
        try:
            # Use model's JSON serialization
            record_json = record.model_dump_json()
            
            # Use record ID as key if not provided
            if key is None:
                key = getattr(record, 'id', str(uuid.uuid4()))
            
            # Produce the message
            self.producer.produce(
                self.topic_name,
                key=str(key),
                value=record_json,
                callback=self._delivery_report
            )
            
            # Poll for delivery reports
            self.producer.poll(0)
            return True
            
        except Exception as e:
            print(f"❌ Error sending record: {e}")
            return False
    
    def send_json_dict(self, data: Dict[str, Any], key: Optional[str] = None) -> bool:
        """Send a dictionary as JSON to Kafka"""
        try:
            # Serialize dictionary to JSON
            record_json = json.dumps(data, default=str)
            
            # Use a default key if not provided
            if key is None:
                key = data.get('id', str(uuid.uuid4()))
            
            # Produce the message
            self.producer.produce(
                self.topic_name,
                key=str(key),
                value=record_json,
                callback=self._delivery_report
            )
            
            # Poll for delivery reports
            self.producer.poll(0)
            return True
            
        except Exception as e:
            print(f"❌ Error sending JSON dict: {e}")
            return False
    
    def flush_and_close(self):
        """Flush pending messages and close producer"""
        print("⏳ Flushing pending messages...")
        self.producer.flush()
        print("✅ Producer closed successfully")


def produce_records(record_type: str = 'job', topic: str = DEFAULT_TOPIC, count: int = None):
    """
    Produce JSON records to Kafka
    
    Args:
        record_type: Type of record to generate ('job', 'order', 'custom')
        topic: Kafka topic name
        count: Number of records to send (None for continuous)
    """
    producer = KafkaJSONProducer(topic)
    
    # Choose record generator based on type
    generators = {
        'job': generate_job_record,
        'order': generate_order_record
    }
    
    if record_type not in generators:
        print(f"❌ Unknown record type: {record_type}")
        print(f"Available types: {list(generators.keys())}")
        return
    
    generator = generators[record_type]
    
    print(f"🚀 Starting to produce {record_type} records to topic: {topic}")
    if count:
        print(f"📊 Will send {count} records")
    else:
        print("🔄 Continuous mode - Press Ctrl+C to stop")
    
    sent_count = 0
    
    try:
        while True:
            # Generate record
            key, record = generator()
            
            # Send to Kafka
            success = producer.send_record(record)
            
            if success:
                sent_count += 1
                print(f"📤 Sent record #{sent_count}: {record_type} - key: {key}")
                
                # Stop if we've sent the requested count
                if count and sent_count >= count:
                    break
            
            # Random delay between records
            time.sleep(random.uniform(0.5, 2.0))
            
    except KeyboardInterrupt:
        print(f"\n🛑 Stopping after sending {sent_count} records...")
    finally:
        producer.flush_and_close()


def produce_custom_json(data: Dict[str, Any], topic: str = DEFAULT_TOPIC, key: Optional[str] = None):
    """
    Produce a custom JSON dictionary to Kafka
    
    Args:
        data: Dictionary to send as JSON
        topic: Kafka topic name
        key: Optional message key
    """
    producer = KafkaJSONProducer(topic)
    
    print(f"📤 Sending custom JSON to topic: {topic}")
    print(f"🔍 Data preview: {json.dumps(data, indent=2, default=str)[:200]}...")
    
    success = producer.send_json_dict(data, key)
    
    if success:
        print("✅ Custom JSON sent successfully")
    else:
        print("❌ Failed to send custom JSON")
    
    producer.flush_and_close()


# ===== CLI INTERFACE =====

def main():
    """Main CLI interface"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Kafka JSON Producer for Shift Left Utils')
    parser.add_argument('--record-type', '-t', default='job', 
                       choices=['job', 'order'],
                       help='Type of record to generate')
    parser.add_argument('--topic', default=DEFAULT_TOPIC,
                       help='Kafka topic name')
    parser.add_argument('--count', '-c', type=int, default=None,
                       help='Number of records to send (default: continuous)')
    parser.add_argument('--custom-json', '-j', type=str,
                       help='Send custom JSON string (overrides record-type)')
    parser.add_argument('--key', '-k', type=str,
                       help='Message key (for custom JSON)')
    
    args = parser.parse_args()
    
    if args.custom_json:
        # Parse and send custom JSON
        try:
            data = json.loads(args.custom_json)
            produce_custom_json(data, args.topic, args.key)
        except json.JSONDecodeError as e:
            print(f"❌ Invalid JSON: {e}")
    else:
        # Send generated records
        produce_records(args.record_type, args.topic, args.count)


if __name__ == "__main__":
    main()