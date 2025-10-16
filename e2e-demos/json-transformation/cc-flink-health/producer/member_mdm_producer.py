#!/usr/bin/env python3
from typing import List, Dict, Any
from confluent_kafka import Producer
from confluent_kafka.serialization import SerializationContext, MessageField
from dotenv import load_dotenv
from models import PersonMDM, generate_member_data
from schema_registry import SchemaRegistryManager
import logging
import os
import sys
from pathlib import Path
from itertools import islice

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Load environment variables from .env file
env_path = Path(__file__).parent / '.env'
if not env_path.exists():
    logger.error(f"Environment file not found at {env_path}. Please create one using .env.template as a reference.")
    sys.exit(1)

load_dotenv(env_path)

class MemberMDMProducer:
    def __init__(self, topic: str, batch_size: int = 10):
        """Initialize the Kafka producer for member MDM records

        Args:
            topic: Target Kafka topic
            batch_size: Number of records to process before flushing (default: 10)
        """
        # Load Kafka configuration
        self.kafka_config = {}
        with open("client.properties") as fh:
            for line in fh:
                line = line.strip()
                if len(line) != 0 and line[0] != "#":
                    parameter, value = line.strip().split('=', 1)
                    self.kafka_config[parameter] = value.strip()

        # Initialize Schema Registry manager
        self.schema_registry = SchemaRegistryManager()

        # Initialize schema and serializer
        self.topic = topic
        self.batch_size = batch_size
        self.initialize_schema_and_serializer()
        
        # Create Kafka producer
        self.producer = Producer(self.kafka_config)

    def initialize_schema_and_serializer(self):
        """Initialize the JSON schema and serializer"""
        # Get or create schema directly from Pydantic model
        self.json_serializer = self.schema_registry.get_or_create_schema_from_pydantic(
            subject_name=f"{self.topic}-value",
            model_class=PersonMDM,
            to_dict=self.person_mdm_to_dict
        )

    def person_mdm_to_dict(self, person_mdm: PersonMDM, ctx: SerializationContext) -> Dict[str, Any]:
        """Convert PersonMDM model to dictionary format for JSON serialization"""
        return person_mdm.model_dump()

    def delivery_report(self, err, msg):
        """Delivery report handler for produced messages"""
        if err is not None:
            logger.error(f'Message delivery failed: {err}')
        else:
            logger.info(f'Message delivered to {msg.topic()} [{msg.partition()}] at offset {msg.offset()}')

    def send_batch(self, batch: List[Dict[str, Any]], operation: str = "INSERT") -> None:
        """Send a batch of records to Kafka

        Args:
            batch: List of dictionaries containing member data
            operation: Operation type (INSERT, UPDATE, DELETE)
        """
        for data in batch:
            # Create the full record using factory method
            record = PersonMDM.create_from_data(
                data=data,
                operation=operation
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

        # Flush after the batch is sent
        logger.info(f"Flushing batch of {len(batch)} records")
        self.producer.flush()

    def send_member_records(self, records: List[Dict[str, Any]], operation: str = "INSERT") -> None:
        """Send member records to Kafka in batches

        Args:
            records: List of dictionaries containing member data
            operation: Operation type (INSERT, UPDATE, DELETE)
        """
        try:
            total_records = len(records)
            logger.info(f"Sending {total_records} records in batches of {self.batch_size}")

            # Process records in batches
            it = iter(records)
            while batch := list(islice(it, self.batch_size)):
                self.send_batch(batch, operation)
                logger.info(f"Processed {len(batch)} records")

        except Exception as e:
            logger.error(f"Error sending member records: {str(e)}")
            raise

    def close(self):
        """Close the Kafka producer"""
        self.producer = None


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Run the MemberMDMProducer")
    parser.add_argument(
        "--num-records",
        type=int,
        default=1,
        help="Number of member records to generate and send (default: 1)",
    )
    parser.add_argument(
        "--batch-size",
        type=int,
        default=10,
        help="Number of records to process before flushing (default: 10)",
    )
    args = parser.parse_args()

    def main_with_num_records(num_records, batch_size):
        producer = MemberMDMProducer(
            topic='person_mdm',
            batch_size=batch_size
        )

        # Generate and send the specified number of member records
        records = generate_member_data(num_records)

        producer.send_member_records(records)

        producer.close()

    main_with_num_records(args.num_records, args.batch_size)