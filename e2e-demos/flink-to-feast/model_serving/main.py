"""Main entry point for model serving application."""

import logging
import sys

import uvicorn

from model_serving.config import settings
from model_serving.utils import setup_logging


def main():
    """Run the model serving application."""
    # Setup logging
    setup_logging(settings.log_level)

    logger = logging.getLogger(__name__)
    logger.info("Starting Driver Risk Prediction API")
    logger.info(f"Feast repo path: {settings.feast_repo_path}")
    logger.info(f"Feature service: {settings.feast_feature_service}")
    logger.info(f"Model type: {settings.model_type}")
    logger.info(f"Model version: {settings.model_version}")
    logger.info(f"Server: {settings.server_host}:{settings.server_port}")

    # Run uvicorn server
    uvicorn.run(
        "model_serving.app:app",
        host=settings.server_host,
        port=settings.server_port,
        log_level=settings.log_level.lower(),
        reload=False,  # Disable reload in production
    )


if __name__ == "__main__":
    main()
