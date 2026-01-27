"""Main entry point for Kafka consumer application."""

import logging
import signal
import sys
from typing import Optional

from kafka_consumer.config import settings
from kafka_consumer.consumer import KafkaFeastConsumer
from kafka_consumer.feast_client import FeastClient
from kafka_consumer.health import HealthCheckServer
from kafka_consumer.utils import setup_logging

logger = logging.getLogger(__name__)

# Global references for signal handling
consumer: Optional[KafkaFeastConsumer] = None
health_server: Optional[HealthCheckServer] = None


def signal_handler(signum, frame):
    """Handle shutdown signals."""
    logger.info(f"Received signal {signum}, initiating graceful shutdown...")
    shutdown()


def shutdown():
    """Gracefully shutdown the application."""
    global consumer, health_server

    if consumer is not None:
        consumer.stop()

    if health_server is not None:
        health_server.stop()

    logger.info("Shutdown complete")


def main():
    """Main application entry point."""
    global consumer, health_server

    # Setup logging
    setup_logging(settings.log_level)
    logger.info("Starting Kafka Consumer for Feast Integration")

    # Register signal handlers
    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGINT, signal_handler)

    try:
        # Initialize Feast client
        logger.info(f"Initializing Feast client from {settings.feast_repo_path}")
        feast_client = FeastClient(
            repo_path=settings.feast_repo_path,
            push_source_name="driver_stats_push_source",
        )

        # Initialize health check server
        logger.info(f"Starting health check server on {settings.health_check_host}:{settings.health_check_port}")
        health_server = HealthCheckServer(
            host=settings.health_check_host,
            port=settings.health_check_port,
            schema_registry_url=settings.schema_registry_url,
        )
        health_server.start()

        # Give health server a moment to start
        import time

        time.sleep(1)

        # Initialize Kafka consumer
        logger.info("Initializing Kafka consumer...")
        consumer = KafkaFeastConsumer(
            kafka_config=settings.get_kafka_config(),
            schema_registry_config=settings.get_schema_registry_config(),
            feast_client=feast_client,
            topic=settings.kafka_topic,
            batch_size=settings.batch_size,
            max_retries=settings.max_retries,
            retry_backoff_ms=settings.retry_backoff_ms,
        )

        # Set consumer reference in health server
        health_server.kafka_consumer = consumer.consumer
        health_server.feast_client = feast_client

        # Start consuming
        logger.info("Starting message consumption...")
        consumer.start()

    except KeyboardInterrupt:
        logger.info("Interrupted by user")
    except Exception as e:
        logger.error(f"Fatal error: {e}", exc_info=True)
        sys.exit(1)
    finally:
        shutdown()


if __name__ == "__main__":
    main()
