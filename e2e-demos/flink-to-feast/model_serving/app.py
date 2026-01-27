"""FastAPI application for model serving."""

import logging
import time
from contextlib import asynccontextmanager
from typing import Optional

from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse

from model_serving.config import settings
from model_serving.feast_client import FeastFeatureClient
from model_serving.model import DriverRiskModel, load_model
from model_serving.schemas import HealthResponse, MetricsResponse, PredictRequest, PredictResponse

logger = logging.getLogger(__name__)

# Global instances
feast_client: Optional[FeastFeatureClient] = None
model: Optional[DriverRiskModel] = None

# Metrics
metrics = {
    "requests_processed": 0,
    "requests_failed": 0,
    "response_times": [],
}


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifespan context manager for startup and shutdown."""
    # Startup
    global feast_client, model

    logger.info("Initializing model serving application...")

    # Initialize Feast client
    try:
        feast_client = FeastFeatureClient(
            repo_path=settings.feast_repo_path,
            feature_service_name=settings.feast_feature_service,
        )
        logger.info("Feast client initialized")
    except Exception as e:
        logger.error(f"Failed to initialize Feast client: {e}", exc_info=True)
        raise

    # Load model
    try:
        model = load_model(
            model_type=settings.model_type,
            model_path=settings.model_path if settings.model_path else None,
            model_version=settings.model_version,
        )
        logger.info(f"Model loaded: {settings.model_type} v{settings.model_version}")
    except Exception as e:
        logger.error(f"Failed to load model: {e}", exc_info=True)
        raise

    logger.info("Model serving application ready")

    yield

    # Shutdown
    logger.info("Shutting down model serving application...")
    if feast_client:
        feast_client.close()
    logger.info("Shutdown complete")


# Create FastAPI app
app = FastAPI(
    title="Driver Risk Prediction API",
    description="Model serving API for driver risk prediction using Feast features",
    version="1.0.0",
    lifespan=lifespan,
)


@app.post("/predict", response_model=PredictResponse)
async def predict(request: PredictRequest):
    """
    Predict driver risk score.

    Fetches features from Feast and runs model inference.
    """
    start_time = time.time()

    try:
        # Fetch features from Feast
        features = feast_client.get_features(
            driver_id=request.driver_id,
            val_to_add=request.val_to_add,
            val_to_add_2=request.val_to_add_2,
        )

        if not features:
            raise HTTPException(status_code=404, detail=f"No features found for driver_id={request.driver_id}")

        # Run model prediction
        prediction = model.predict_from_features(features)

        # Calculate response time
        response_time = (time.time() - start_time) * 1000  # Convert to milliseconds
        metrics["response_times"].append(response_time)
        # Keep only last 100 response times for average calculation
        if len(metrics["response_times"]) > 100:
            metrics["response_times"] = metrics["response_times"][-100:]

        metrics["requests_processed"] += 1

        return PredictResponse(
            prediction=prediction,
            features_used=features,
            model_version=settings.model_version,
        )

    except HTTPException:
        raise
    except Exception as e:
        metrics["requests_failed"] += 1
        logger.error(f"Prediction failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Prediction failed: {str(e)}")


@app.get("/health", response_model=HealthResponse)
async def health():
    """Health check endpoint."""
    feast_connected = False
    model_loaded = False

    try:
        feast_connected = feast_client.health_check() if feast_client else False
    except Exception as e:
        logger.error(f"Feast health check failed: {e}")

    model_loaded = model is not None

    status = "healthy" if (feast_connected and model_loaded) else "unhealthy"

    return HealthResponse(
        status=status,
        feast_connected=feast_connected,
        model_loaded=model_loaded,
    )


@app.get("/metrics", response_model=MetricsResponse)
async def get_metrics():
    """Get service metrics."""
    avg_response_time = None
    if metrics["response_times"]:
        avg_response_time = sum(metrics["response_times"]) / len(metrics["response_times"])

    return MetricsResponse(
        requests_processed=metrics["requests_processed"],
        requests_failed=metrics["requests_failed"],
        average_response_time_ms=round(avg_response_time, 2) if avg_response_time else None,
    )


@app.get("/")
async def root():
    """Root endpoint with API information."""
    return {
        "service": "Driver Risk Prediction API",
        "version": "1.0.0",
        "endpoints": {
            "predict": "/predict",
            "health": "/health",
            "metrics": "/metrics",
            "docs": "/docs",
        },
    }
