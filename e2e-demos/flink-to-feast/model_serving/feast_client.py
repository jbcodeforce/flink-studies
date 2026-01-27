"""Feast client wrapper for fetching features."""

import logging
from typing import Dict, Optional

from feast import FeatureStore

logger = logging.getLogger(__name__)


class FeastFeatureClient:
    """Wrapper around Feast FeatureStore for fetching features."""

    def __init__(self, repo_path: str, feature_service_name: str = "driver_activity_v3"):
        """
        Initialize Feast feature client.

        Args:
            repo_path: Path to Feast feature repository
            feature_service_name: Name of the FeatureService to use
        """
        self.repo_path = repo_path
        self.feature_service_name = feature_service_name
        self._store: Optional[FeatureStore] = None

    @property
    def store(self) -> FeatureStore:
        """Get or create FeatureStore instance."""
        if self._store is None:
            logger.info(f"Initializing Feast FeatureStore from {self.repo_path}")
            self._store = FeatureStore(repo_path=self.repo_path)
        return self._store

    def get_features(
        self,
        driver_id: int,
        val_to_add: Optional[int] = None,
        val_to_add_2: Optional[int] = None,
    ) -> Dict[str, float]:
        """
        Fetch features for a driver from Feast online store.

        Args:
            driver_id: Driver ID to fetch features for
            val_to_add: Optional value for on-demand feature transformation
            val_to_add_2: Optional second value for on-demand feature transformation

        Returns:
            Dictionary of feature names to values

        Raises:
            Exception: If feature fetching fails
        """
        try:
            # Prepare entity rows
            entity_rows = [
                {
                    "driver_id": driver_id,
                }
            ]

            # Add request features if provided
            if val_to_add is not None:
                entity_rows[0]["val_to_add"] = val_to_add
            if val_to_add_2 is not None:
                entity_rows[0]["val_to_add_2"] = val_to_add_2

            # Get feature service
            feature_service = self.store.get_feature_service(self.feature_service_name)

            # Fetch online features
            logger.debug(f"Fetching features for driver_id={driver_id} using service={self.feature_service_name}")
            feature_vector = self.store.get_online_features(
                features=feature_service,
                entity_rows=entity_rows,
            )

            # Convert to dictionary
            features_dict = feature_vector.to_dict()

            # Extract feature values (remove entity keys and timestamps)
            result = {}
            for key, value_list in features_dict.items():
                # Skip entity keys and timestamps
                if key in ["driver_id", "event_timestamp", "created"]:
                    continue
                # Get first value from list
                if value_list and len(value_list) > 0:
                    result[key] = value_list[0] if value_list[0] is not None else 0.0

            logger.debug(f"Fetched {len(result)} features for driver_id={driver_id}")
            return result

        except Exception as e:
            logger.error(f"Failed to fetch features from Feast: {e}", exc_info=True)
            raise

    def health_check(self) -> bool:
        """
        Check if Feast store is accessible.

        Returns:
            True if healthy, False otherwise
        """
        try:
            # Try to access the store
            _ = self.store
            # Try to list feature services
            _ = self.store.list_feature_services()
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
