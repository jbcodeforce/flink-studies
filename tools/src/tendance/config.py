#!/usr/bin/env python3
"""
Tendance Configuration Management

This module provides centralized configuration management for the Tendance application.
Configuration can be loaded from YAML files, environment variables, or defaults.
"""

import os
import logging
from pathlib import Path
from typing import Optional, Dict, Any, List
from datetime import datetime

import yaml
from pydantic import BaseModel, Field, field_validator
from pydantic_settings import BaseSettings

logger = logging.getLogger(__name__)


class APIConfig(BaseModel):
    """Stack Exchange API configuration"""
    api_key: Optional[str] = Field(default=None, description="Stack Exchange API key")
    site: str = Field(default="stackoverflow", description="Stack Exchange site")
    default_page_size: int = Field(default=30, ge=1, le=100, description="Default page size")
    max_retries: int = Field(default=3, ge=0, description="Maximum retry attempts")
    timeout_seconds: int = Field(default=30, ge=1, description="Request timeout")
    respect_backoff: bool = Field(default=True, description="Respect API backoff headers")
    user_agent: str = Field(default="Tendance/1.0", description="User agent string")
    max_pages_cli: int = Field(default=10, ge=1, description="Maximum pages to fetch in CLI mode")
    retry_backoff_factor: float = Field(default=1.5, ge=1.0, description="Retry backoff multiplier")
    
    @field_validator('api_key')
    @classmethod
    def validate_api_key(cls, v):
        # Handle common placeholder values
        if v in [None, '', 'null', 'your_stack_exchange_api_key_here', 'your_api_key_here']:
            return None
        return v


class SubjectConfig(BaseModel):
    """Subject-specific configuration"""
    name: str = Field(description="Subject display name")
    tags: List[str] = Field(description="Default tags for this subject")
    min_score: int = Field(default=0, description="Default minimum score")
    description: Optional[str] = Field(default=None, description="Subject description")


class OutputConfig(BaseModel):
    """Output configuration"""
    default_directory: str = Field(default="./output", description="Default output directory")
    default_formats: List[str] = Field(default=["json"], description="Default output formats")
    timestamp_format: str = Field(default="%Y%m%d_%H%M%S", description="Timestamp format for filenames")
    include_metadata: bool = Field(default=True, description="Include metadata in outputs")
    
    @field_validator('default_formats')
    @classmethod
    def validate_formats(cls, v):
        valid_formats = {'json', 'csv', 'markdown'}
        for fmt in v:
            if fmt not in valid_formats:
                raise ValueError(f"Invalid format: {fmt}. Valid formats: {valid_formats}")
        return v


class UIConfig(BaseModel):
    """Web UI configuration"""
    default_port: int = Field(default=8501, ge=1, le=65535, description="Default dashboard port")
    host: str = Field(default="localhost", description="Dashboard host")
    auto_open: bool = Field(default=False, description="Auto-open browser")
    theme: str = Field(default="light", description="UI theme")
    refresh_interval: int = Field(default=300, ge=60, description="Data refresh interval in seconds")


class LoggingConfig(BaseModel):
    """Logging configuration"""
    level: str = Field(default="INFO", description="Log level")
    format: str = Field(
        default="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
        description="Log format"
    )
    file: Optional[str] = Field(default=None, description="Log file path")
    max_size: int = Field(default=10485760, description="Max log file size in bytes (10MB)")
    backup_count: int = Field(default=5, description="Number of log backup files")


class TendanceConfig(BaseSettings):
    """Main Tendance configuration"""
    
    # Core settings
    version: str = Field(default="0.1.0", description="Application version")
    debug: bool = Field(default=False, description="Debug mode")
    
    # Component configurations
    api: APIConfig = Field(default_factory=APIConfig, description="API configuration")
    output: OutputConfig = Field(default_factory=OutputConfig, description="Output configuration")
    ui: UIConfig = Field(default_factory=UIConfig, description="UI configuration")
    logging: LoggingConfig = Field(default_factory=LoggingConfig, description="Logging configuration")
    
    # Subject configurations
    subjects: Dict[str, SubjectConfig] = Field(
        default_factory=lambda: {
            "apache-flink": SubjectConfig(
                name="Apache Flink",
                tags=["apache-flink", "flink-sql", "flink-streaming", "flink-cep"],
                min_score=0,
                description="Apache Flink stream processing framework"
            ),
            "kafka": SubjectConfig(
                name="Apache Kafka",
                tags=["apache-kafka", "kafka-streams", "kafka-connect"],
                min_score=0,
                description="Apache Kafka event streaming platform"
            ),
            "spark": SubjectConfig(
                name="Apache Spark",
                tags=["apache-spark", "pyspark", "spark-sql"],
                min_score=0,
                description="Apache Spark unified analytics engine"
            )
        },
        description="Subject-specific configurations"
    )
    
    model_config = {"env_prefix": "TENDANCE_", "env_nested_delimiter": "__"}
    
    def get_subject_config(self, subject: str) -> Optional[SubjectConfig]:
        """Get configuration for a specific subject"""
        return self.subjects.get(subject)
    
    def get_tags_for_subject(self, subject: str) -> List[str]:
        """Get default tags for a subject"""
        subject_config = self.get_subject_config(subject)
        if subject_config:
            return subject_config.tags
        # Fallback: use subject name as tag
        return [subject] if subject else []


class ConfigLoader:
    """Configuration loader with YAML file support"""
    
    def __init__(self, config_file: Optional[str] = None):
        """Initialize config loader
        
        Args:
            config_file: Path to YAML config file, or None to use CONFIG_FILE env var
        """
        self.config_file = config_file or os.getenv("CONFIG_FILE")
        self._config: Optional[TendanceConfig] = None
    
    def load(self) -> TendanceConfig:
        """Load configuration from file, environment, and defaults"""
        if self._config is not None:
            return self._config
        
        config_data = {}
        
        # Load from YAML file if specified
        if self.config_file and Path(self.config_file).exists():
            try:
                with open(self.config_file, 'r', encoding='utf-8') as f:
                    file_config = yaml.safe_load(f) or {}
                    config_data.update(file_config)
                    logger.info(f"Loaded configuration from: {self.config_file}")
            except Exception as e:
                logger.warning(f"Failed to load config file {self.config_file}: {e}")
        elif self.config_file:
            logger.warning(f"Config file not found: {self.config_file}")
        
        # Create configuration with file data and environment variables
        try:
            self._config = TendanceConfig(**config_data)
            logger.info("Configuration loaded successfully")
            return self._config
        except Exception as e:
            logger.error(f"Failed to load configuration: {e}")
            # Return default configuration as fallback
            self._config = TendanceConfig()
            return self._config
    
    def reload(self) -> TendanceConfig:
        """Reload configuration from file"""
        self._config = None
        return self.load()
    
    def save_example(self, file_path: str):
        """Save an example configuration file"""
        example_config = {
            'version': '0.1.0',
            'debug': False,
            'api': {
                'api_key': None,  # Use TENDANCE_API__API_KEY environment variable
                'site': 'stackoverflow',
                'default_page_size': 30,
                'max_retries': 3,
                'timeout_seconds': 30,
                'user_agent': 'Tendance/1.0',
                'max_pages_cli': 10,
                'retry_backoff_factor': 1.5
            },
            'output': {
                'default_directory': './output',
                'default_formats': ['json', 'csv'],
                'timestamp_format': '%Y%m%d_%H%M%S',
                'include_metadata': True
            },
            'ui': {
                'default_port': 8501,
                'host': 'localhost',
                'auto_open': False,
                'theme': 'light',
                'refresh_interval': 300
            },
            'logging': {
                'level': 'INFO',
                'format': '%(asctime)s - %(name)s - %(levelname)s - %(message)s',
                'file': None,
                'max_size': 10485760,
                'backup_count': 5
            },
            'subjects': {
                'apache-flink': {
                    'name': 'Apache Flink',
                    'tags': ['apache-flink', 'flink-sql', 'flink-streaming', 'flink-cep'],
                    'min_score': 0,
                    'description': 'Apache Flink stream processing framework'
                },
                'kafka': {
                    'name': 'Apache Kafka', 
                    'tags': ['apache-kafka', 'kafka-streams', 'kafka-connect'],
                    'min_score': 0,
                    'description': 'Apache Kafka event streaming platform'
                },
                'custom-subject': {
                    'name': 'Custom Subject',
                    'tags': ['custom-tag1', 'custom-tag2'],
                    'min_score': 5,
                    'description': 'Example custom subject configuration'
                }
            }
        }
        
        with open(file_path, 'w', encoding='utf-8') as f:
            yaml.dump(example_config, f, default_flow_style=False, indent=2)
        
        logger.info(f"Example configuration saved to: {file_path}")


# Global configuration loader
_config_loader: Optional[ConfigLoader] = None


def get_config() -> TendanceConfig:
    """Get the global configuration instance"""
    global _config_loader
    if _config_loader is None:
        _config_loader = ConfigLoader()
    return _config_loader.load()


def reload_config() -> TendanceConfig:
    """Reload the global configuration"""
    global _config_loader
    if _config_loader is None:
        _config_loader = ConfigLoader()
    return _config_loader.reload()


def set_config_file(config_file: str):
    """Set the configuration file path"""
    global _config_loader
    _config_loader = ConfigLoader(config_file)


def create_example_config(file_path: str = "tendance-config.yaml"):
    """Create an example configuration file"""
    loader = ConfigLoader()
    loader.save_example(file_path)


# Configure logging based on loaded config
def setup_logging():
    """Setup logging based on configuration"""
    config = get_config()
    log_config = config.logging
    
    # Set log level
    level = getattr(logging, log_config.level.upper(), logging.INFO)
    
    # Configure root logger
    logging.basicConfig(
        level=level,
        format=log_config.format,
        force=True
    )
    
    # Add file handler if specified
    if log_config.file:
        from logging.handlers import RotatingFileHandler
        
        log_file = Path(log_config.file)
        log_file.parent.mkdir(parents=True, exist_ok=True)
        
        file_handler = RotatingFileHandler(
            log_config.file,
            maxBytes=log_config.max_size,
            backupCount=log_config.backup_count
        )
        file_handler.setFormatter(logging.Formatter(log_config.format))
        
        # Add to root logger
        root_logger = logging.getLogger()
        root_logger.addHandler(file_handler)
    
    logger.info(f"Logging configured: level={log_config.level}, file={log_config.file}")


# Initialize logging on module import
setup_logging()
