"""Health check server for Kubernetes probes."""

import logging
import threading
import time
from typing import Optional

from fastapi import FastAPI
from fastapi.responses import JSONResponse
from uvicorn import Config, Server

logger = logging.getLogger(__name__)


class HealthCheckServer:
    """HTTP server for health checks and metrics."""

    def __init__(
        self,
        host: str = "0.0.0.0",
        port: int = 8080,
        kafka_consumer=None,
        feast_client=None,
        schema_registry_url: Optional[str] = None,
    ):
        """
        Initialize health check server.

        Args:
            host: Host to bind to
            port: Port to listen on
            kafka_consumer: Kafka consumer instance for health checks
            feast_client: Feast client instance for health checks
            schema_registry_url: Schema Registry URL for connectivity check
        """
        self.host = host
        self.port = port
        self.kafka_consumer = kafka_consumer
        self.feast_client = feast_client
        self.schema_registry_url = schema_registry_url
        self.app = FastAPI(title="Kafka Consumer Health Check")
        self.server: Optional[Server] = None
        self.server_thread: Optional[threading.Thread] = None
        self._setup_routes()

        # Metrics
        self.metrics = {
            "messages_consumed": 0,
            "messages_pushed": 0,
            "errors": 0,
            "last_message_time": None,
        }

    def _setup_routes(self):
        """Setup FastAPI routes."""

        @self.app.get("/health")
        async def health():
            """Basic health check endpoint."""
            return {"status": "healthy"}

        @self.app.get("/health/ready")
        async def readiness():
            """Readiness probe - checks if service is ready to accept traffic."""
            checks = {
                "kafka": self._check_kafka(),
                "feast": self._check_feast(),
                "schema_registry": self._check_schema_registry(),
            }
            all_healthy = all(checks.values())
            status_code = 200 if all_healthy else 503
            return JSONResponse(
                status_code=status_code,
                content={"status": "ready" if all_healthy else "not ready", "checks": checks},
            )

        @self.app.get("/health/live")
        async def liveness():
            """Liveness probe - checks if service is alive."""
            return {"status": "alive"}

        @self.app.get("/metrics")
        async def metrics():
            """Metrics endpoint."""
            return {
                "metrics": self.metrics,
                "consumer_lag": self._get_consumer_lag(),
            }

    def _check_kafka(self) -> bool:
        """Check Kafka connectivity."""
        if self.kafka_consumer is None:
            return False
        try:
            # Try to get metadata or check consumer is alive
            metadata = self.kafka_consumer.list_topics(timeout=5)
            return metadata is not None
        except Exception as e:
            logger.debug(f"Kafka health check failed: {e}")
            return False

    def _check_feast(self) -> bool:
        """Check Feast connectivity."""
        if self.feast_client is None:
            return False
        return self.feast_client.health_check()

    def _check_schema_registry(self) -> bool:
        """Check Schema Registry connectivity."""
        if self.schema_registry_url is None:
            return True  # Not required if not configured
        try:
            import requests

            response = requests.get(f"{self.schema_registry_url}/subjects", timeout=5)
            return response.status_code == 200
        except Exception as e:
            logger.debug(f"Schema Registry health check failed: {e}")
            return False

    def _get_consumer_lag(self) -> Optional[dict]:
        """Get consumer lag information."""
        # This is a placeholder - actual lag calculation would require
        # accessing consumer position and topic end offsets
        return None

    def update_metrics(
        self,
        messages_consumed: int = 0,
        messages_pushed: int = 0,
        errors: int = 0,
    ):
        """Update metrics."""
        self.metrics["messages_consumed"] += messages_consumed
        self.metrics["messages_pushed"] += messages_pushed
        self.metrics["errors"] += errors
        if messages_consumed > 0:
            self.metrics["last_message_time"] = time.time()

    def start(self):
        """Start the health check server in a background thread."""
        if self.server_thread is not None and self.server_thread.is_alive():
            logger.warning("Health check server is already running")
            return

        config = Config(self.app, host=self.host, port=self.port, log_level="warning")
        self.server = Server(config)

        def run_server():
            try:
                self.server.run()
            except Exception as e:
                logger.error(f"Health check server error: {e}")

        self.server_thread = threading.Thread(target=run_server, daemon=True)
        self.server_thread.start()
        logger.info(f"Health check server started on {self.host}:{self.port}")

    def stop(self):
        """Stop the health check server."""
        if self.server is not None:
            self.server.should_exit = True
            if self.server_thread is not None:
                self.server_thread.join(timeout=5)
            logger.info("Health check server stopped")
