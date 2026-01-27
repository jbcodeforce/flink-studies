"""Simple demo model for driver risk prediction."""

import logging
from typing import Dict, Optional

import numpy as np

logger = logging.getLogger(__name__)


class DriverRiskModel:
    """Simple rule-based model for predicting driver risk score."""

    def __init__(self, model_version: str = "1.0.0"):
        """
        Initialize the model.

        Args:
            model_version: Model version identifier
        """
        self.model_version = model_version
        logger.info(f"Initialized DriverRiskModel version {model_version}")

    def predict(
        self,
        conv_rate: float,
        acc_rate: float,
        avg_daily_trips: float,
        conv_rate_plus_val1: Optional[float] = None,
        conv_rate_plus_val2: Optional[float] = None,
    ) -> Dict[str, any]:
        """
        Predict driver risk score based on features.

        Args:
            conv_rate: Conversion rate (0.0 to 1.0)
            acc_rate: Acceptance rate (0.0 to 1.0)
            avg_daily_trips: Average daily trips
            conv_rate_plus_val1: Optional transformed feature
            conv_rate_plus_val2: Optional transformed feature

        Returns:
            Dictionary with risk_score and risk_level
        """
        # Normalize inputs
        conv_rate = max(0.0, min(1.0, conv_rate))
        acc_rate = max(0.0, min(1.0, acc_rate))
        avg_daily_trips = max(0.0, avg_daily_trips)

        # Simple rule-based scoring:
        # - Lower conv_rate and acc_rate = higher risk
        # - More trips = higher activity = potentially higher risk (but also more experience)
        # - We weight conv_rate and acc_rate more heavily as they indicate quality

        # Risk components (0.0 = no risk, 1.0 = maximum risk)
        conv_risk = 1.0 - conv_rate  # Lower conversion = higher risk
        acc_risk = 1.0 - acc_rate  # Lower acceptance = higher risk

        # Trip risk: normalize trips (assuming 0-2000 trips per day range)
        # More trips can indicate both high activity (good) and potential fatigue (bad)
        # We use a sigmoid-like function to cap the risk contribution
        trip_risk = min(1.0, avg_daily_trips / 2000.0)

        # Weighted risk score
        risk_score = (conv_risk * 0.4) + (acc_risk * 0.4) + (trip_risk * 0.2)

        # Clamp to [0, 1]
        risk_score = max(0.0, min(1.0, risk_score))

        # Determine risk level
        if risk_score >= 0.7:
            risk_level = "high"
        elif risk_score >= 0.4:
            risk_level = "medium"
        else:
            risk_level = "low"

        # If transformed features are available, we could use them for additional insights
        # For now, we just use the base features

        logger.debug(
            f"Prediction: risk_score={risk_score:.3f}, risk_level={risk_level}, "
            f"conv_rate={conv_rate:.3f}, acc_rate={acc_rate:.3f}, trips={avg_daily_trips:.1f}"
        )

        return {
            "risk_score": round(risk_score, 4),
            "risk_level": risk_level,
        }

    def predict_from_features(self, features: Dict[str, float]) -> Dict[str, any]:
        """
        Predict from a dictionary of features.

        Args:
            features: Dictionary of feature names to values

        Returns:
            Dictionary with risk_score and risk_level
        """
        # Extract required features with defaults
        conv_rate = features.get("conv_rate", 0.5)
        acc_rate = features.get("acc_rate", 0.5)
        avg_daily_trips = features.get("avg_daily_trips", 0.0)

        # Extract optional transformed features
        conv_rate_plus_val1 = features.get("conv_rate_plus_val1")
        conv_rate_plus_val2 = features.get("conv_rate_plus_val2")

        return self.predict(
            conv_rate=conv_rate,
            acc_rate=acc_rate,
            avg_daily_trips=avg_daily_trips,
            conv_rate_plus_val1=conv_rate_plus_val1,
            conv_rate_plus_val2=conv_rate_plus_val2,
        )


def load_model(model_type: str = "rule_based", model_path: Optional[str] = None, model_version: str = "1.0.0"):
    """
    Load a model based on type.

    Args:
        model_type: Type of model to load (rule_based, sklearn, etc.)
        model_path: Path to model file (for pre-trained models)
        model_version: Model version identifier

    Returns:
        Model instance
    """
    if model_type == "rule_based":
        return DriverRiskModel(model_version=model_version)
    elif model_type == "sklearn" and model_path:
        # For future: load sklearn model from file
        # import joblib
        # return joblib.load(model_path)
        raise NotImplementedError("sklearn model loading not yet implemented")
    else:
        raise ValueError(f"Unknown model type: {model_type}")
