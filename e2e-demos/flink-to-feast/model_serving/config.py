"""Configuration management for model serving application."""

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    # Feast Configuration
    feast_repo_path: str = Field(
        default="./feature_repo",
        description="Path to Feast feature repository",
    )
    feast_feature_service: str = Field(
        default="driver_activity_v3",
        description="Feast FeatureService name to use",
    )

    # Model Configuration
    model_type: str = Field(
        default="rule_based",
        description="Type of model (rule_based, sklearn, etc.)",
    )
    model_path: str = Field(
        default="",
        description="Path to pre-trained model file (if using pre-trained model)",
    )
    model_version: str = Field(
        default="1.0.0",
        description="Model version identifier",
    )

    # Server Configuration
    server_host: str = Field(
        default="0.0.0.0",
        description="Server host to bind to",
    )
    server_port: int = Field(
        default=8000,
        description="Server port",
    )

    # Application Configuration
    log_level: str = Field(
        default="INFO",
        description="Logging level",
    )


# Global settings instance
settings = Settings()
