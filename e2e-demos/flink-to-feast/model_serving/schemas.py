"""Request and response schemas for model serving API."""

from typing import Dict, Optional

from pydantic import BaseModel, Field


class PredictRequest(BaseModel):
    """Request schema for prediction endpoint."""

    driver_id: int = Field(..., description="Driver ID to get prediction for")
    val_to_add: Optional[int] = Field(
        default=None,
        description="Value to add for on-demand feature transformation",
    )
    val_to_add_2: Optional[int] = Field(
        default=None,
        description="Second value to add for on-demand feature transformation",
    )

    model_config = {"json_schema_extra": {"example": {"driver_id": 1001, "val_to_add": 1000, "val_to_add_2": 2000}}}


class PredictionResult(BaseModel):
    """Prediction result schema."""

    risk_score: float = Field(..., description="Risk score (0.0 to 1.0)")
    risk_level: str = Field(..., description="Risk level (low, medium, high)")

    model_config = {"json_schema_extra": {"example": {"risk_score": 0.35, "risk_level": "low"}}}


class PredictResponse(BaseModel):
    """Response schema for prediction endpoint."""

    prediction: PredictionResult = Field(..., description="Model prediction result")
    features_used: Dict[str, float] = Field(..., description="Features used for prediction")
    model_version: str = Field(..., description="Model version used")

    model_config = {
        "json_schema_extra": {
            "example": {
                "prediction": {"risk_score": 0.35, "risk_level": "low"},
                "features_used": {"conv_rate": 0.8, "acc_rate": 0.9, "avg_daily_trips": 500.0},
                "model_version": "1.0.0",
            }
        }
    }


class HealthResponse(BaseModel):
    """Health check response schema."""

    status: str = Field(..., description="Service status")
    feast_connected: bool = Field(..., description="Whether Feast is connected")
    model_loaded: bool = Field(..., description="Whether model is loaded")


class MetricsResponse(BaseModel):
    """Metrics response schema."""

    requests_processed: int = Field(..., description="Total requests processed")
    requests_failed: int = Field(..., description="Total requests failed")
    average_response_time_ms: Optional[float] = Field(
        default=None,
        description="Average response time in milliseconds",
    )
