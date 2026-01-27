"""Feast client wrapper for pushing data to feature store."""

import logging
from datetime import datetime
from typing import Optional

import pandas as pd

from feast import FeatureStore
from feast.data_source import PushMode

logger = logging.getLogger(__name__)


class FeastClient:
    """Wrapper around Feast FeatureStore for pushing data."""

    def __init__(self, repo_path: str, push_source_name: str = "driver_stats_push_source"):
        """
        Initialize Feast client.

        Args:
            repo_path: Path to Feast feature repository
            push_source_name: Name of the push source in Feast
        """
        self.repo_path = repo_path
        self.push_source_name = push_source_name
        self._store: Optional[FeatureStore] = None

    @property
    def store(self) -> FeatureStore:
        """Get or create FeatureStore instance."""
        if self._store is None:
            logger.info(f"Initializing Feast FeatureStore from {self.repo_path}")
            self._store = FeatureStore(repo_path=self.repo_path)
        return self._store

    def push_data(
        self,
        data: list[dict],
        push_mode: PushMode = PushMode.ONLINE_AND_OFFLINE,
    ) -> bool:
        """
        Push data to Feast feature store.

        Args:
            data: List of dictionaries containing feature data
            push_mode: Push mode (ONLINE, OFFLINE, or ONLINE_AND_OFFLINE)

        Returns:
            True if successful, False otherwise
        """
        if not data:
            logger.warning("No data to push to Feast")
            return True

        try:
            # Convert to DataFrame
            df = pd.DataFrame(data)

            # Ensure required columns exist
            required_columns = ["driver_id", "event_timestamp"]
            missing_columns = [col for col in required_columns if col not in df.columns]
            if missing_columns:
                raise ValueError(f"Missing required columns: {missing_columns}")

            # Ensure event_timestamp is datetime
            if not pd.api.types.is_datetime64_any_dtype(df["event_timestamp"]):
                df["event_timestamp"] = pd.to_datetime(df["event_timestamp"])

            # Add created timestamp if not present
            if "created" not in df.columns:
                df["created"] = datetime.now()

            # Ensure created is datetime
            if not pd.api.types.is_datetime64_any_dtype(df["created"]):
                df["created"] = pd.to_datetime(df["created"])

            logger.debug(f"Pushing {len(df)} records to Feast push source: {self.push_source_name}")
            self.store.push(self.push_source_name, df, to=push_mode)
            logger.info(f"Successfully pushed {len(df)} records to Feast")
            return True

        except Exception as e:
            logger.error(f"Failed to push data to Feast: {e}", exc_info=True)
            return False

    def health_check(self) -> bool:
        """
        Check if Feast store is accessible.

        Returns:
            True if healthy, False otherwise
        """
        try:
            # Try to access the store
            _ = self.store
            return True
        except Exception as e:
            logger.error(f"Feast health check failed: {e}")
            return False

    def close(self):
        """Close Feast store connection."""
        if self._store is not None:
            # Feast doesn't have an explicit close method, but we can clear the reference
            self._store = None
            logger.info("Feast store connection closed")
