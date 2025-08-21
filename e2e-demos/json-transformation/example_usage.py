#!/usr/bin/env python3
"""
Example usage of the Kafka JSON Producer
"""

import json
from kafka_json_producer import (
    KafkaJSONProducer, 
    generate_amx_record, 
    generate_execution_state_record,
    generate_simple_event,
    produce_custom_json
)

def example_1_simple_usage():
    """Example 1: Send a few simple events"""
    print("=== Example 1: Simple Events ===")
    
    producer = KafkaJSONProducer("test-events")
    
    for i in range(3):
        event = generate_simple_event()
        producer.send_record(event)
        print(f"Sent event {i+1}: {event.event_type}")
    
    producer.flush_and_close()


def example_2_amx_records():
    """Example 2: Send AMX records"""
    print("\n=== Example 2: AMX Records ===")
    
    producer = KafkaJSONProducer("amx-records")
    
    for i in range(2):
        record = generate_amx_record()
        producer.send_record(record)
        print(f"Sent AMX record {i+1}: {record.title}")
    
    producer.flush_and_close()


def example_3_custom_json():
    """Example 3: Send custom JSON dictionary"""
    print("\n=== Example 3: Custom JSON ===")
    
    custom_data = {
        "record_id": "custom_001",
        "timestamp": "2024-01-15T10:30:00Z",
        "event_type": "data_processing",
        "tenant": "acme_corp",
        "metadata": {
            "source_system": "data_pipeline",
            "processing_stage": "enrichment",
            "record_count": 1500
        },
        "status": "completed",
        "duration_ms": 2340
    }
    
    produce_custom_json(custom_data, "custom-events", "custom_001")


def example_4_execution_state():
    """Example 4: Send record execution state"""
    print("\n=== Example 4: Record Execution State ===")
    
    producer = KafkaJSONProducer("execution-state")
    
    record = generate_execution_state_record()
    producer.send_record(record)
    print(f"Sent execution state: {record.recordname}")
    
    producer.flush_and_close()


if __name__ == "__main__":
    print("🚀 Kafka JSON Producer Examples")
    print("Make sure your Kafka cluster is running and environment variables are set!")
    print()
    
    # Run all examples
    example_1_simple_usage()
    example_2_amx_records()
    example_3_custom_json()
    example_4_execution_state()
    
    print("\n✅ All examples completed!")
    print("\nTo run the producer in CLI mode:")
    print("python kafka_json_producer.py --record-type simple --count 5")
    print("python kafka_json_producer.py --record-type amx --topic my-topic")
    print('python kafka_json_producer.py --custom-json \'{"test": "data"}\' --topic custom')