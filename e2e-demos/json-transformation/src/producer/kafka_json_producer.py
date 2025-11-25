#!/usr/bin/env python3
"""
Generic Kafka Producer with Schema Registry Integration

This producer supports:
- JSON serialization of Pydantic models and dictionaries
- Schema Registry integration with automatic schema validation
- Configurable Schema Registry authentication
- Schema caching for performance
- Optional schema validation bypass

Environment Variables:
- SCHEMA_REGISTRY_URL: Schema Registry endpoint (default: http://localhost:8081)
- SCHEMA_REGISTRY_USER: Basic auth username (optional)
- SCHEMA_REGISTRY_PASSWORD: Basic auth password (optional)

Dependencies:
- confluent-kafka[schema-registry]>=2.3.0
- pydantic>=2.0.0
- jsonschema>=4.0.0
"""

import json
import random
import time
import uuid

from typing import Optional, Dict, Any
from confluent_kafka import Producer
from confluent_kafka.schema_registry import SchemaRegistryClient
from confluent_kafka.schema_registry.json_schema import JSONSerializer
from pydantic import BaseModel, Field
import os
import jsonschema
from jsonschema import validate
from models import generate_job_record, generate_order_record

# Kafka Configuration from Environment Variables
KAFKA_BROKERS = os.getenv('KAFKA_BOOTSTRAP_SERVERS', 'localhost:9094')
KAFKA_CERT = os.getenv('KAFKA_CERT', '')
KAFKA_USER = os.getenv('KAFKA_USER', '')
KAFKA_PASSWORD = os.getenv('KAFKA_PASSWORD', '')
KAFKA_SASL_MECHANISM = os.getenv('KAFKA_SASL_MECHANISM', 'PLAIN')
KAFKA_SECURITY_PROTOCOL = os.getenv('KAFKA_SECURITY_PROTOCOL', 'PLAINTEXT')
DEFAULT_TOPIC = os.getenv('KAFKA_TOPIC', 'raw-orders')

# Schema Registry Configuration
SCHEMA_REGISTRY_URL = os.getenv('SCHEMA_REGISTRY_URL', 'http://localhost:8081')
SCHEMA_REGISTRY_USER = os.getenv('SCHEMA_REGISTRY_USER', '')
SCHEMA_REGISTRY_PASSWORD = os.getenv('SCHEMA_REGISTRY_PASSWORD', '')


class KafkaJSONProducer:
    """Flexible Kafka JSON Producer with Schema Registry support"""
    
    def __init__(self, topic_name: str = DEFAULT_TOPIC, use_schema_registry: bool = True):
        self.topic_name = topic_name
        self.use_schema_registry = use_schema_registry
        self.producer = self._create_producer()
        self.schema_registry_client = None
        self.cached_schemas = {}
        
        if self.use_schema_registry:
            self.schema_registry_client = self._create_schema_registry_client()
        
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
    
    def _create_schema_registry_client(self) -> SchemaRegistryClient:
        """Create and configure Schema Registry client"""
        conf = {'url': SCHEMA_REGISTRY_URL}
        
        if SCHEMA_REGISTRY_USER:
            conf.update({
                'basic.auth.user.info': f'{SCHEMA_REGISTRY_USER}:{SCHEMA_REGISTRY_PASSWORD}'
            })
        
        print("=== Schema Registry Configuration ===")
        print(f"URL: {conf['url']}")
        print(f"Auth enabled: {bool(SCHEMA_REGISTRY_USER)}")
        print("====================================")
        
        return SchemaRegistryClient(conf)
    
    def _delivery_report(self, err, msg):
        """Callback for message delivery reports"""
        if err is not None:
            print(f"❌ Message delivery failed: {err}")
        else:
            print(f"✅ Message delivered to {msg.topic()} [{msg.partition()}] offset {msg.offset()}")
    
    def _get_schema_for_topic(self, topic_name: str) -> Optional[Dict[str, Any]]:
        """Fetch JSON schema for a topic from Schema Registry"""
        if not self.use_schema_registry or not self.schema_registry_client:
            return None
        
        # Check cache first
        if topic_name in self.cached_schemas:
            return self.cached_schemas[topic_name]
        
        try:
            # Schema subject naming convention: {topic}-value
            subject_name = f"{topic_name}-value"
            
            # Get latest schema version
            schema_metadata = self.schema_registry_client.get_latest_version(subject_name)
            schema_str = schema_metadata.schema.schema_str
            
            # Parse JSON schema
            schema_dict = json.loads(schema_str)
            
            # Cache the schema
            self.cached_schemas[topic_name] = schema_dict
            
            print(f"📋 Retrieved schema for topic '{topic_name}' from Schema Registry")
            return schema_dict
            
        except Exception as e:
            print(f"⚠️ Could not fetch schema for topic '{topic_name}': {e}")
            return None
    
    def _validate_against_schema(self, data: Dict[str, Any], schema: Dict[str, Any]) -> bool:
        """Validate data against JSON schema"""
        try:
            validate(instance=data, schema=schema)
            return True
        except jsonschema.exceptions.ValidationError as e:
            print(f"❌ Schema validation failed: {e.message}")
            print(f"📍 Failed at path: {' -> '.join(str(p) for p in e.absolute_path)}")
            return False
        except Exception as e:
            print(f"❌ Unexpected validation error: {e}")
            return False
    
    def get_schema_info(self, topic_name: Optional[str] = None) -> Optional[Dict[str, Any]]:
        """Get schema information for a topic (for debugging/inspection)"""
        topic = topic_name or self.topic_name
        if not self.use_schema_registry:
            return {"error": "Schema Registry not enabled"}
        
        schema = self._get_schema_for_topic(topic)
        if schema:
            return {
                "topic": topic,
                "subject": f"{topic}-value",
                "schema_type": schema.get("$schema", "Unknown"),
                "title": schema.get("title", "No title"),
                "description": schema.get("description", "No description"),
                "required_fields": schema.get("required", []),
                "properties_count": len(schema.get("properties", {}))
            }
        return {"error": f"No schema found for topic: {topic}"}
    
    def send_record(self, record: BaseModel, key: Optional[str] = None) -> bool:
        """Send a Pydantic model as JSON to Kafka with Schema Registry validation"""
        try:
            # Convert Pydantic model to dictionary for validation
            record_dict = record.model_dump()
            
            # Get schema for topic and validate if Schema Registry is enabled
            if self.use_schema_registry:
                schema = self._get_schema_for_topic(self.topic_name)
                if schema:
                    if not self._validate_against_schema(record_dict, schema):
                        print(f"❌ Record validation failed for topic '{self.topic_name}'")
                        return False
                    print(f"✅ Record validated successfully against schema")
                else:
                    print(f"⚠️ No schema found for topic '{self.topic_name}', proceeding without validation")
            
            # Serialize to JSON
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
        """Send a dictionary as JSON to Kafka with Schema Registry validation"""
        try:
            # Get schema for topic and validate if Schema Registry is enabled
            if self.use_schema_registry:
                schema = self._get_schema_for_topic(self.topic_name)
                if schema:
                    if not self._validate_against_schema(data, schema):
                        print(f"❌ Dictionary validation failed for topic '{self.topic_name}'")
                        return False
                    print(f"✅ Dictionary validated successfully against schema")
                else:
                    print(f"⚠️ No schema found for topic '{self.topic_name}', proceeding without validation")
            
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


def produce_records(record_type: str = 'job', topic: str = DEFAULT_TOPIC, count: int = None, use_schema_registry: bool = True):
    """
    Produce JSON records to Kafka
    
    Args:
        record_type: Type of record to generate ('job', 'order', 'custom')
        topic: Kafka topic name
        count: Number of records to send (None for continuous)
        use_schema_registry: Whether to use Schema Registry validation
    """
    producer = KafkaJSONProducer(topic, use_schema_registry=use_schema_registry)
    
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


def produce_custom_json(data: Dict[str, Any], topic: str = DEFAULT_TOPIC, key: Optional[str] = None, use_schema_registry: bool = True):
    """
    Produce a custom JSON dictionary to Kafka
    
    Args:
        data: Dictionary to send as JSON
        topic: Kafka topic name
        key: Optional message key
        use_schema_registry: Whether to use Schema Registry validation
    """
    producer = KafkaJSONProducer(topic, use_schema_registry=use_schema_registry)
    
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
    parser.add_argument('--no-schema-registry', action='store_true',
                       help='Disable Schema Registry validation')
    
    args = parser.parse_args()
    
    # Determine if Schema Registry should be used
    use_schema_registry = not args.no_schema_registry
    
    if args.custom_json:
        # Parse and send custom JSON
        try:
            data = json.loads(args.custom_json)
            produce_custom_json(data, args.topic, args.key, use_schema_registry)
        except json.JSONDecodeError as e:
            print(f"❌ Invalid JSON: {e}")
    else:
        # Send generated records
        produce_records(args.record_type, args.topic, args.count, use_schema_registry)


if __name__ == "__main__":
    main()