"""Kafka consumer with Avro deserialization and Feast integration."""

import logging
import time
from typing import Any, Dict, List, Optional

from confluent_kafka import Consumer, KafkaError, KafkaException
from confluent_kafka.schema_registry import SchemaRegistryClient
from confluent_kafka.schema_registry.avro import AvroDeserializer
from confluent_kafka.serialization import MessageField, SerializationContext

from kafka_consumer.feast_client import FeastClient
from kafka_consumer.utils import transform_message_to_feast_format, validate_feast_record

logger = logging.getLogger(__name__)


class KafkaFeastConsumer:
    """Kafka consumer that pushes messages to Feast feature store."""

    def __init__(
        self,
        kafka_config: Dict[str, str],
        schema_registry_config: Dict[str, str],
        feast_client: FeastClient,
        topic: str,
        batch_size: int = 1,
        max_retries: int = 3,
        retry_backoff_ms: int = 1000,
    ):
        """
        Initialize Kafka consumer.

        Args:
            kafka_config: Kafka consumer configuration
            schema_registry_config: Schema Registry configuration
            feast_client: Feast client instance
            topic: Kafka topic to consume from
            batch_size: Number of messages to batch before pushing
            max_retries: Maximum retries for failed operations
            retry_backoff_ms: Initial backoff time in milliseconds
        """
        self.kafka_config = kafka_config
        self.schema_registry_config = schema_registry_config
        self.feast_client = feast_client
        self.topic = topic
        self.batch_size = batch_size
        self.max_retries = max_retries
        self.retry_backoff_ms = retry_backoff_ms

        # Initialize Schema Registry client
        self.schema_registry_client = SchemaRegistryClient(schema_registry_config)

        # Initialize Avro deserializer
        self.avro_deserializer = AvroDeserializer(
            self.schema_registry_client,
        )

        # Initialize Kafka consumer
        self.consumer: Optional[Consumer] = None
        self._running = False
        self._shutdown_requested = False

    def _create_consumer(self) -> Consumer:
        """Create and configure Kafka consumer."""
        consumer = Consumer(self.kafka_config)
        consumer.subscribe([self.topic])
        logger.info(f"Subscribed to topic: {self.topic}")
        return consumer

    def _deserialize_message(self, message) -> Optional[Dict[str, Any]]:
        """
        Deserialize Avro message from Kafka.

        Args:
            message: Kafka message object

        Returns:
            Deserialized message dictionary or None if deserialization fails
        """
        try:
            context = SerializationContext(self.topic, MessageField.VALUE)
            deserialized = self.avro_deserializer(message.value(), context)
            return deserialized
        except Exception as e:
            logger.error(f"Failed to deserialize message: {e}", exc_info=True)
            return None

    def _process_batch(self, batch: List[Dict[str, Any]]) -> bool:
        """
        Process a batch of messages by pushing to Feast.

        Args:
            batch: List of transformed message dictionaries

        Returns:
            True if successful, False otherwise
        """
        if not batch:
            return True

        for attempt in range(self.max_retries):
            try:
                success = self.feast_client.push_data(batch)
                if success:
                    return True
                else:
                    logger.warning(f"Feast push returned False, attempt {attempt + 1}/{self.max_retries}")
            except Exception as e:
                logger.error(f"Feast push failed, attempt {attempt + 1}/{self.max_retries}: {e}")

            if attempt < self.max_retries - 1:
                backoff_time = self.retry_backoff_ms * (2 ** attempt) / 1000.0
                logger.info(f"Retrying in {backoff_time:.2f} seconds...")
                time.sleep(backoff_time)

        logger.error(f"Failed to push batch after {self.max_retries} attempts")
        return False

    def _process_message(self, message) -> bool:
        """
        Process a single Kafka message.

        Args:
            message: Kafka message object

        Returns:
            True if processed successfully, False otherwise
        """
        # Deserialize message
        deserialized = self._deserialize_message(message)
        if deserialized is None:
            return False

        # Transform to Feast format
        feast_record = transform_message_to_feast_format(deserialized)
        if feast_record is None:
            logger.error("Failed to transform message to Feast format")
            return False

        # Validate record
        if not validate_feast_record(feast_record):
            logger.error("Feast record validation failed")
            return False

        # Push to Feast (single message batch)
        return self._process_batch([feast_record])

    def start(self):
        """Start consuming messages from Kafka."""
        if self._running:
            logger.warning("Consumer is already running")
            return

        self.consumer = self._create_consumer()
        self._running = True
        self._shutdown_requested = False

        logger.info("Starting Kafka consumer...")
        batch: List[Dict[str, Any]] = []

        try:
            while not self._shutdown_requested:
                msg = self.consumer.poll(timeout=1.0)

                if msg is None:
                    # No message received, process any pending batch
                    if batch and self.batch_size > 1:
                        self._process_batch(batch)
                        batch = []
                    continue

                if msg.error():
                    if msg.error().code() == KafkaError._PARTITION_EOF:
                        # End of partition event - not an error
                        logger.debug(f"Reached end of partition: {msg.topic()}[{msg.partition()}]")
                    else:
                        logger.error(f"Consumer error: {msg.error()}")
                    continue

                # Deserialize and transform message
                deserialized = self._deserialize_message(msg)
                if deserialized is None:
                    logger.error(f"Failed to deserialize message from {msg.topic()}[{msg.partition()}]@{msg.offset()}")
                    continue

                feast_record = transform_message_to_feast_format(deserialized)
                if feast_record is None:
                    logger.error(f"Failed to transform message from {msg.topic()}[{msg.partition()}]@{msg.offset()}")
                    continue

                if not validate_feast_record(feast_record):
                    logger.error(f"Feast record validation failed for {msg.topic()}[{msg.partition()}]@{msg.offset()}")
                    continue

                # Add to batch or process immediately
                if self.batch_size > 1:
                    batch.append(feast_record)
                    if len(batch) >= self.batch_size:
                        success = self._process_batch(batch)
                        if success:
                            batch = []
                        else:
                            logger.error(f"Failed to process batch, keeping {len(batch)} records")
                else:
                    # Process immediately (batch size = 1)
                    success = self._process_batch([feast_record])
                    if not success:
                        logger.error(f"Failed to process message from {msg.topic()}[{msg.partition()}]@{msg.offset()}")

        except KeyboardInterrupt:
            logger.info("Received interrupt signal")
        except KafkaException as e:
            logger.error(f"Kafka exception: {e}", exc_info=True)
        except Exception as e:
            logger.error(f"Unexpected error: {e}", exc_info=True)
        finally:
            self.stop()

    def stop(self):
        """Stop the consumer gracefully."""
        if not self._running:
            return

        logger.info("Stopping Kafka consumer...")
        self._shutdown_requested = True
        self._running = False

        if self.consumer is not None:
            try:
                self.consumer.close()
                logger.info("Kafka consumer closed")
            except Exception as e:
                logger.error(f"Error closing consumer: {e}")

    def list_topics(self, timeout: float = 5.0):
        """List topics for health check."""
        if self.consumer is None:
            return None
        return self.consumer.list_topics(timeout=timeout)
