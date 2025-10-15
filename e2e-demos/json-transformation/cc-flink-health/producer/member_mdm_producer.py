#!/usr/bin/env python3
from datetime import datetime
from typing import Optional, List, Dict, Any
from pydantic import BaseModel, Field
from confluent_kafka import Producer
from confluent_kafka.schema_registry import SchemaRegistryClient
from confluent_kafka.schema_registry.json_schema import JSONSerializer
from confluent_kafka.serialization import SerializationContext, MessageField
from dotenv import load_dotenv
import json
import uuid
import logging
import os
import sys
from pathlib import Path

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Load environment variables from .env file
env_path = Path(__file__).parent / '.env'
if not env_path.exists():
    logger.error(f"Environment file not found at {env_path}. Please create one using .env.template as a reference.")
    sys.exit(1)

load_dotenv(env_path)

# Validate required environment variables
required_env_vars = ['SCHEMA_REGISTRY_URL', 'SCHEMA_REGISTRY_KEY', 'SCHEMA_REGISTRY_SECRET']
missing_vars = [var for var in required_env_vars if not os.getenv(var)]
if missing_vars:
    logger.error(f"Missing required environment variables: {', '.join(missing_vars)}")
    logger.error("Please set them in your .env file")
    sys.exit(1)

class Headers(BaseModel):
    """Headers for the member record"""
    op: str = Field(description="Operation type (INSERT, UPDATE, DELETE)")
    ts_ms: int = Field(description="Timestamp in milliseconds")
    transaction_id: str = Field(description="Unique transaction identifier")

class SystemOfRecord(BaseModel):
    """System of record information"""
    sourceSystem: str = Field(description="Source system identifier")
    sourceEntity: str = Field(description="Source entity name")
    sourcePublishedDate: str = Field(description="Date when record was published")
    sourceCorrelationReference: str = Field(description="Correlation reference")
    entityKey: str = Field(description="Unique entity identifier")

class PersonMDM(BaseModel):
    """Person MDM record following Flink table schema"""
    headers: Headers
    data: str = Field(description="Main data payload")
    beforeData: Optional[str] = Field(default=None, description="Previous state of data for updates")
    systemOfRecord: SystemOfRecord

class MemberMDMProducer:
    def __init__(self, topic: str):
        """Initialize the Kafka producer for member MDM records

        Args:
            topic: Target Kafka topic
        """
        # Load Kafka configuration
        self.kafka_config = {}
        with open("client.properties") as fh:
            for line in fh:
                line = line.strip()
                if len(line) != 0 and line[0] != "#":
                    parameter, value = line.strip().split('=', 1)
                    self.kafka_config[parameter] = value.strip()

        # Load Schema Registry configuration
        schema_registry_conf = {
            'url': os.getenv('SCHEMA_REGISTRY_URL'),
            'basic.auth.user.info': f"{os.getenv('SCHEMA_REGISTRY_KEY')}:{os.getenv('SCHEMA_REGISTRY_SECRET')}"
        }

        # Create Schema Registry client
        schema_registry_client = SchemaRegistryClient(schema_registry_conf)

        # Load the JSON schema
        schema_path = Path(__file__).parent / "person_mdm.json"
        if not schema_path.exists():
            logger.error(f"Schema file not found at {schema_path}")
            sys.exit(1)

        with open(schema_path, "r") as f:
            schema_str = f.read()

        # Create JSON serializer
        self.json_serializer = JSONSerializer(
            schema_str,
            schema_registry_client,
            self.person_mdm_to_dict
        )

        self.topic = topic
        self.producer = Producer(self.kafka_config)

    def person_mdm_to_dict(self, person_mdm: PersonMDM, ctx: SerializationContext) -> Dict[str, Any]:
        """Convert PersonMDM model to dictionary format for JSON serialization"""
        return {
            "headers": {
                "op": person_mdm.headers.op,
                "ts_ms": person_mdm.headers.ts_ms,
                "transaction_id": person_mdm.headers.transaction_id
            },
            "data": person_mdm.data,
            "beforeData": person_mdm.beforeData,
            "systemOfRecord": {
                "sourceSystem": person_mdm.systemOfRecord.sourceSystem,
                "sourceEntity": person_mdm.systemOfRecord.sourceEntity,
                "sourcePublishedDate": person_mdm.systemOfRecord.sourcePublishedDate,
                "sourceCorrelationReference": person_mdm.systemOfRecord.sourceCorrelationReference,
                "entityKey": person_mdm.systemOfRecord.entityKey
            }
        }

    def delivery_report(self, err, msg):
        """Delivery report handler for produced messages"""
        if err is not None:
            logger.error(f'Message delivery failed: {err}')
        else:
            logger.info(f'Message delivered to {msg.topic()} [{msg.partition()}] at offset {msg.offset()}')

    def send_member_records(self, records: List[Dict[str, Any]], operation: str = "INSERT") -> None:
        """Send member records to Kafka

        Args:
            records: List of dictionaries containing member data
            operation: Operation type (INSERT, UPDATE, DELETE)
        """
        try:
            # Create record timestamp
            current_ts = int(datetime.now().timestamp() * 1000)
            
            # Create a unique transaction ID
            transaction_id = str(uuid.uuid4())

            for data in records:
                # Create the full record
                record = PersonMDM(
                    headers=Headers(
                        op=operation,
                        ts_ms=current_ts,
                        transaction_id=transaction_id
                    ),
                    data=json.dumps(data),  # Convert data dict to JSON string
                    systemOfRecord=SystemOfRecord(
                        sourceSystem="MEMBER_MDM",
                        sourceEntity="PERSON",
                        sourcePublishedDate=datetime.now().isoformat(),
                        sourceCorrelationReference=transaction_id,
                        entityKey=str(data.get('member_id', uuid.uuid4()))
                    )
                )

                # Serialize the record using JSON Schema
                value = self.json_serializer(
                    record,
                    SerializationContext(self.topic, MessageField.VALUE)
                )

                logger.info(f"Sending member record with ID: {record.systemOfRecord.entityKey} to topic {self.topic}")
                
                # Send to Kafka
                self.producer.produce(
                    topic=self.topic,
                    key=record.systemOfRecord.entityKey,
                    value=value,
                    on_delivery=self.delivery_report
                )
                self.producer.poll(0)  # Trigger delivery reports

            # Wait for any outstanding messages to be delivered
            self.producer.flush()

        except Exception as e:
            logger.error(f"Error sending member record: {str(e)}")
            raise

    def close(self):
        """Close the Kafka producer"""
        self.producer = None


import random

FIRST_NAMES = [
    "Alice", "Bob", "Charlie", "Diana", "Eva", "Frank", "Grace", "Henry", "Ivy", "Jack",
    "Karen", "Leo", "Mona", "Ned", "Olivia", "Paul", "Quincy", "Rita", "Sam", "Tina"
]

LAST_NAMES = [
    "Smith", "Johnson", "Williams", "Brown", "Jones", "Miller", "Davis", "Garcia",
    "Martinez", "Robinson", "Clark", "Rodriguez", "Lewis", "Lee", "Walker", "Hall",
    "Allen", "Young", "King", "Wright"
]

CITIES = [
    "Springfield", "Riverside", "Greenwood", "Madison", "Franklin", "Clinton", "Fairview"
]
STREETS = [
    "123 Main St", "456 Maple Ave", "789 Oak Ln", "101 Pine Rd", "202 Cedar Dr"
]

STATES_AND_ZIPS = [
    ("IL", "62701"),
    ("CA", "90210"),
    ("NY", "10001"),
    ("TX", "73301"),
    ("FL", "33101"),
]

GENDERS = ["M", "F", "O"]

def generate_member_data(nb_records: int = 30) -> list[dict]:
    """Generate a list of diverse synthetic member data records."""
    records = []
    logger.info(f"Generating {nb_records} member records")
    used_names = set()
    for _ in range(nb_records):
        # Ensure some diversity in names
        first_name = random.choice(FIRST_NAMES)
        last_name = random.choice(LAST_NAMES)
        # Optionally, try to avoid repeat full names
        attempts = 0
        while (first_name, last_name) in used_names and attempts < 10:
            first_name = random.choice(FIRST_NAMES)
            last_name = random.choice(LAST_NAMES)
            attempts += 1
        used_names.add((first_name, last_name))

        state, zip_code = random.choice(STATES_AND_ZIPS)

        # Generate plausible date of birth between 1950 and 2010
        year = random.randint(1950, 2010)
        month = random.randint(1, 12)
        day = random.randint(1, 28)  # To avoid invalid days
        date_of_birth = f"{year:04d}-{month:02d}-{day:02d}"

        gender = random.choice(GENDERS)

        local_part = f"{first_name.lower()}.{last_name.lower()}".replace(" ", "")
        email = f"{local_part}@example.com"

        phone = "{}-{:03d}-{:04d}".format(
            random.randint(100, 999),
            random.randint(100, 999),
            random.randint(1000, 9999)
        )

        address = {
            "street": random.choice(STREETS),
            "city": random.choice(CITIES),
            "state": state,
            "zip": zip_code
        }

        records.append({
            "member_id": str(uuid.uuid4()),
            "first_name": first_name,
            "last_name": last_name,
            "date_of_birth": date_of_birth,
            "gender": gender,
            "email": email,
            "phone": phone,
            "address": address
        })
    return records
    

if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Run the MemberMDMProducer")
    parser.add_argument(
        "--num-records",
        type=int,
        default=1,
        help="Number of member records to generate and send (default: 1)",
    )
    args = parser.parse_args()

    def main_with_num_records(num_records):
        producer = MemberMDMProducer(
            topic='member_mdm'
        )

        # Generate and send the specified number of member records
        records = generate_member_data(num_records)

        producer.send_member_records(records)

        producer.close()

    main_with_num_records(args.num_records)