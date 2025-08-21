#!/usr/bin/env python3
"""
Generic Kafka JSON Producer for Shift Left Utils
Supports multiple record types with configurable schemas
"""

import json
import random
import time
import uuid
from datetime import datetime, timezone
from decimal import Decimal
from typing import Optional, Dict, Any
from confluent_kafka import Producer
from pydantic import BaseModel, Field
import os


# Kafka Configuration from Environment Variables
KAFKA_BROKERS = os.getenv('KAFKA_BOOTSTRAP_SERVERS', 'localhost:9092')
KAFKA_CERT = os.getenv('KAFKA_CERT', '')
KAFKA_USER = os.getenv('KAFKA_USER', '')
KAFKA_PASSWORD = os.getenv('KAFKA_PASSWORD', '')
KAFKA_SASL_MECHANISM = os.getenv('KAFKA_SASL_MECHANISM', 'PLAIN')
KAFKA_SECURITY_PROTOCOL = os.getenv('KAFKA_SECURITY_PROTOCOL', 'PLAINTEXT')
DEFAULT_TOPIC = os.getenv('KAFKA_TOPIC', 'test-records')


# ===== RECORD MODELS (Choose/Customize Based on Your Needs) =====

class AMXRecord(BaseModel):
    """AMX Record structure based on src_amx_record schema"""
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    tenantId: str = Field(..., description="Tenant identifier")
    cmxId: Optional[int] = Field(None, description="Legacy CMx identifier")
    title: Optional[str] = Field(None, description="Record title")
    createdOnDate: str = Field(default_factory=lambda: datetime.now(timezone.utc).isoformat())
    createdByUserId: Optional[str] = Field(None, description="Creator user ID")
    createdByUserIdp: Optional[str] = Field(None, description="Creator identity provider")
    createdByUserFullName: Optional[str] = Field(None, description="Creator full name")
    sourceTemplateId: Optional[str] = Field(None, description="Source template ID")
    sourceTemplateCmxId: Optional[int] = Field(None, description="Legacy template CMx ID")
    sourceTemplateTitle: Optional[str] = Field(None, description="Template title")
    sourceTemplateRevision: Optional[str] = Field(None, description="Template revision")
    sourceTemplateRevisedOnDate: Optional[str] = Field(None, description="Template revision date")
    sourceTemplateRevisedByUserId: Optional[str] = Field(None, description="Template revisor user ID")
    sourceTemplateRevisedByUserIdp: Optional[str] = Field(None, description="Template revisor IDP")
    sourceTemplateLifecycle: Optional[str] = Field(None, description="Template lifecycle")
    status: str = Field(default="INITIALIZING", description="Record status")
    statusModifiedOnDate: Optional[str] = Field(None, description="Status modification date")
    statusModifiedByUserId: Optional[str] = Field(None, description="Status modifier user ID")
    statusModifiedByUserIdp: Optional[str] = Field(None, description="Status modifier IDP")
    percentComplete: Optional[float] = Field(default=0.0, description="Completion percentage")
    numberOfItemsCompleted: Optional[int] = Field(default=0, description="Completed items count")
    numberOfItemsToComplete: Optional[int] = Field(default=1, description="Total items to complete")
    productFamilyGroupsAndSelectedOptions: Optional[Dict[str, str]] = Field(default_factory=dict)
    roleGroupLocationId: Optional[int] = Field(None, description="Role group location ID")
    
    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat(),
            Decimal: lambda v: str(v)
        }


class RecordExecutionState(BaseModel):
    """Record execution state based on event_definitions.py"""
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    ts_ms: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    tenant_id: Optional[str] = Field(None, description="Tenant identifier")
    deleted: bool = Field(default=False, description="Deletion flag")
    app_id: str = Field(..., description="Application identifier")
    object_state_id: Optional[str] = Field(None, description="Object state ID")
    owner: Optional[str] = Field(None, description="Record owner")
    title: Optional[str] = Field(None, description="Record title")
    dueDate: Optional[str] = Field(None, description="Due date")
    duration: Optional[str] = Field(None, description="Duration")
    closedDate: Optional[str] = Field(None, description="Closed date")
    launchDate: Optional[str] = Field(None, description="Launch date")
    recordname: Optional[str] = Field(None, description="Record name")
    recordtype: Optional[str] = Field(None, description="Record type")
    description: Optional[str] = Field(None, description="Record description")
    durationUnit: Optional[str] = Field(None, description="Duration unit")
    modifiedDate: Optional[str] = Field(None, description="Modified date")
    recordNumber: Optional[str] = Field(None, description="Record number")
    recordStatus: Optional[str] = Field(None, description="Record status")
    affectedsites: Optional[str] = Field(None, description="Affected sites")
    completedDate: Optional[str] = Field(None, description="Completed date")
    parentRecordId: Optional[str] = Field(None, description="Parent record ID")
    executionPlanId: Optional[str] = Field(None, description="Execution plan ID")
    childWorkflowIds: Optional[str] = Field(None, description="Child workflow IDs")
    workflowNodeState: Optional[str] = Field(None, description="Workflow node state")
    workflowRevision: Optional[str] = Field(None, description="Workflow revision")
    recordConfigurationId: Optional[str] = Field(None, description="Record configuration ID")
    durationInBusinessDays: int = Field(default=1, description="Duration in business days")
    excludeRecordsFromGlobalSearch: Optional[str] = Field(None)
    excludeRecordsFromMyCollection: Optional[str] = Field(None)
    data_type: Optional[str] = Field(None, description="Data type")
    series_id: Optional[str] = Field(None, description="Series ID")
    revision_number: int = Field(default=1, description="Revision number")
    source_ts_ms: Optional[datetime] = Field(None, description="Source timestamp")
    dl_landed_at: Optional[str] = Field(None, description="Data lake landing timestamp")
    
    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat(),
            Decimal: lambda v: str(v)
        }


class SimpleEvent(BaseModel):
    """Simple event structure for testing"""
    event_id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    event_type: str = Field(..., description="Type of event")
    timestamp: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    user_id: Optional[str] = Field(None, description="User identifier")
    data: Dict[str, Any] = Field(default_factory=dict, description="Event data")
    
    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat(),
            Decimal: lambda v: str(v)
        }


# ===== KAFKA PRODUCER IMPLEMENTATION =====

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
            'client.id': f'shift-left-json-producer-{uuid.uuid4().hex[:8]}'
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


# ===== SAMPLE DATA GENERATORS =====

def generate_amx_record() -> AMXRecord:
    """Generate sample AMX record"""
    statuses = ['INITIALIZING', 'OPEN', 'IN_PROCESS', 'DATA_COMPLETE', 'CLOSED_ACCEPTED']
    idps = ['QX', 'OKTA', 'MCIDP']
    
    return AMXRecord(
        tenantId=f"tenant_{random.randint(1, 10)}",
        cmxId=random.randint(1000, 9999),
        title=f"Sample Record {random.randint(1, 1000)}",
        createdByUserId=f"user_{random.randint(1, 100)}",
        createdByUserIdp=random.choice(idps),
        createdByUserFullName=f"User {random.randint(1, 100)}",
        sourceTemplateId=str(uuid.uuid4()),
        sourceTemplateTitle=f"Template {random.randint(1, 50)}",
        sourceTemplateLifecycle=random.choice(['PILOT', 'PRODUCTION']),
        status=random.choice(statuses),
        percentComplete=round(random.uniform(0, 100), 2),
        numberOfItemsCompleted=random.randint(0, 20),
        numberOfItemsToComplete=random.randint(1, 20)
    )


def generate_execution_state_record() -> RecordExecutionState:
    """Generate sample record execution state"""
    return RecordExecutionState(
        app_id=f"app_{random.randint(1, 10)}",
        tenant_id=f"tenant_{random.randint(1, 5)}",
        title=f"Execution Record {random.randint(1, 1000)}",
        recordname=f"record_{random.randint(1, 100)}",
        recordtype=random.choice(['PROCESS', 'WORKFLOW', 'TASK']),
        description=f"Sample record execution for testing - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
        recordStatus=random.choice(['OPEN', 'IN_PROCESS', 'COMPLETED']),
        durationInBusinessDays=random.randint(1, 30),
        revision_number=random.randint(1, 5)
    )


def generate_simple_event() -> SimpleEvent:
    """Generate simple test event"""
    event_types = ['user_action', 'data_update', 'system_event']
    
    return SimpleEvent(
        event_type=random.choice(event_types),
        user_id=f"user_{random.randint(1, 100)}",
        data={
            'action': random.choice(['create', 'update', 'delete', 'view']),
            'resource': random.choice(['record', 'node', 'capture']),
            'value': random.randint(1, 1000),
            'metadata': {
                'source': 'kafka_producer',
                'version': '1.0'
            }
        }
    )


# ===== MAIN FUNCTIONS =====

def produce_records(record_type: str = 'simple', topic: str = DEFAULT_TOPIC, count: int = None):
    """
    Produce JSON records to Kafka
    
    Args:
        record_type: Type of record to generate ('amx', 'execution_state', 'simple', 'custom')
        topic: Kafka topic name
        count: Number of records to send (None for continuous)
    """
    producer = KafkaJSONProducer(topic)
    
    # Choose record generator based on type
    generators = {
        'amx': generate_amx_record,
        'execution_state': generate_execution_state_record,
        'simple': generate_simple_event
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
            record = generator()
            
            # Send to Kafka
            success = producer.send_record(record)
            
            if success:
                sent_count += 1
                print(f"📤 Sent record #{sent_count}: {record_type} - ID: {record.id}")
                
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
    parser.add_argument('--record-type', '-t', default='simple', 
                       choices=['amx', 'execution_state', 'simple'],
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