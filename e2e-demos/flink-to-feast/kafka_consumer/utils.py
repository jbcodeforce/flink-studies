"""Utility functions for message transformation and validation."""

import logging
from datetime import datetime
from typing import Any, Dict, Optional

import pandas as pd

logger = logging.getLogger(__name__)


def transform_message_to_feast_format(message_value: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    """
    Transform Kafka message to Feast push source format.

    Expected Feast schema:
    - driver_id: entity key
    - event_timestamp: timestamp field
    - created: created timestamp (optional, defaults to now)
    - conv_rate: Float32
    - acc_rate: Float32
    - avg_daily_trips: Int64

    Args:
        message_value: Deserialized Avro message from Kafka

    Returns:
        Transformed dictionary in Feast format, or None if transformation fails
    """
    try:
        # Extract required fields
        if "driver_id" not in message_value:
            logger.error("Missing required field: driver_id")
            return None

        # Build Feast record
        feast_record = {
            "driver_id": message_value["driver_id"],
        }

        # Handle event_timestamp
        if "event_timestamp" in message_value:
            timestamp = message_value["event_timestamp"]
            if isinstance(timestamp, (int, float)):
                # Assume Unix timestamp in seconds or milliseconds
                if timestamp > 1e10:  # Milliseconds
                    timestamp = timestamp / 1000
                feast_record["event_timestamp"] = datetime.fromtimestamp(timestamp)
            elif isinstance(timestamp, str):
                feast_record["event_timestamp"] = pd.to_datetime(timestamp)
            else:
                feast_record["event_timestamp"] = timestamp
        else:
            # Default to current time if not present
            feast_record["event_timestamp"] = datetime.now()

        # Handle created timestamp
        if "created" in message_value:
            created = message_value["created"]
            if isinstance(created, (int, float)):
                if created > 1e10:  # Milliseconds
                    created = created / 1000
                feast_record["created"] = datetime.fromtimestamp(created)
            elif isinstance(created, str):
                feast_record["created"] = pd.to_datetime(created)
            else:
                feast_record["created"] = created
        else:
            feast_record["created"] = datetime.now()

        # Extract feature values
        for field in ["conv_rate", "acc_rate", "avg_daily_trips"]:
            if field in message_value:
                feast_record[field] = message_value[field]
            else:
                logger.warning(f"Missing optional field: {field}")

        return feast_record

    except Exception as e:
        logger.error(f"Failed to transform message: {e}", exc_info=True)
        return None


def validate_feast_record(record: Dict[str, Any]) -> bool:
    """
    Validate that a record has required fields for Feast.

    Args:
        record: Dictionary to validate

    Returns:
        True if valid, False otherwise
    """
    required_fields = ["driver_id", "event_timestamp"]
    missing_fields = [field for field in required_fields if field not in record]
    if missing_fields:
        logger.error(f"Missing required fields: {missing_fields}")
        return False
    return True


def setup_logging(log_level: str = "INFO"):
    """
    Configure logging for the application.

    Args:
        log_level: Logging level (DEBUG, INFO, WARNING, ERROR, CRITICAL)
    """
    import sys

    logging.basicConfig(
        level=getattr(logging, log_level.upper()),
        format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
        stream=sys.stdout,
    )
