"""Configuration management for Kafka consumer."""

import os
from typing import Optional

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    # Kafka Configuration
    kafka_bootstrap_servers: str = Field(
        default="localhost:9092",
        description="Kafka broker addresses (comma-separated)",
    )
    kafka_topic: str = Field(
        default="driver-stats",
        description="Kafka topic name to consume from",
    )
    kafka_consumer_group: str = Field(
        default="feast-consumer-group",
        description="Kafka consumer group ID",
    )
    kafka_auto_offset_reset: str = Field(
        default="earliest",
        description="Kafka auto offset reset policy",
    )
    kafka_enable_auto_commit: bool = Field(
        default=True,
        description="Enable auto commit for Kafka consumer",
    )
    kafka_session_timeout_ms: int = Field(
        default=30000,
        description="Kafka session timeout in milliseconds",
    )
    kafka_max_poll_interval_ms: int = Field(
        default=300000,
        description="Kafka max poll interval in milliseconds",
    )

    # Schema Registry Configuration
    schema_registry_url: str = Field(
        default="http://localhost:8081",
        description="Schema Registry URL",
    )
    schema_registry_basic_auth_user_info: Optional[str] = Field(
        default=None,
        description="Schema Registry basic auth credentials (format: username:password)",
    )

    # Feast Configuration
    feast_repo_path: str = Field(
        default="./feature_repo",
        description="Path to Feast feature repository",
    )

    # Health Check Configuration
    health_check_port: int = Field(
        default=8080,
        description="Port for health check HTTP server",
    )
    health_check_host: str = Field(
        default="0.0.0.0",
        description="Host for health check HTTP server",
    )

    # Application Configuration
    log_level: str = Field(
        default="INFO",
        description="Logging level",
    )
    batch_size: int = Field(
        default=1,
        description="Number of messages to batch before pushing to Feast",
    )
    max_retries: int = Field(
        default=3,
        description="Maximum number of retries for failed operations",
    )
    retry_backoff_ms: int = Field(
        default=1000,
        description="Initial backoff time in milliseconds for retries",
    )

    @field_validator("kafka_auto_offset_reset")
    @classmethod
    def validate_auto_offset_reset(cls, v: str) -> str:
        """Validate auto offset reset value."""
        allowed_values = ["earliest", "latest", "none"]
        if v.lower() not in allowed_values:
            raise ValueError(f"auto_offset_reset must be one of {allowed_values}")
        return v.lower()

    @field_validator("log_level")
    @classmethod
    def validate_log_level(cls, v: str) -> str:
        """Validate log level."""
        allowed_values = ["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"]
        if v.upper() not in allowed_values:
            raise ValueError(f"log_level must be one of {allowed_values}")
        return v.upper()

    def get_kafka_config(self) -> dict:
        """Get Kafka consumer configuration."""
        config = {
            "bootstrap.servers": self.kafka_bootstrap_servers,
            "group.id": self.kafka_consumer_group,
            "auto.offset.reset": self.kafka_auto_offset_reset,
            "enable.auto.commit": str(self.kafka_enable_auto_commit).lower(),
            "session.timeout.ms": self.kafka_session_timeout_ms,
            "max.poll.interval.ms": self.kafka_max_poll_interval_ms,
        }
        return config

    def get_schema_registry_config(self) -> dict:
        """Get Schema Registry configuration."""
        config = {
            "url": self.schema_registry_url,
        }
        if self.schema_registry_basic_auth_user_info:
            config["basic.auth.user.info"] = self.schema_registry_basic_auth_user_info
        return config


# Global settings instance
settings = Settings()
