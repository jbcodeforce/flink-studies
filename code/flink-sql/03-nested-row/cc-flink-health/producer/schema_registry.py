#!/usr/bin/env python3
from confluent_kafka.schema_registry import SchemaRegistryClient, Schema
from confluent_kafka.schema_registry.json_schema import JSONSerializer
from confluent_kafka.schema_registry.avro import AvroSerializer
from confluent_kafka.serialization import SerializationContext
from typing import Any, Callable, Dict, Optional, Union, Type
from pydantic import BaseModel
import json
import logging
import os
from pathlib import Path

logger = logging.getLogger(__name__)

class SchemaRegistryManager:
    def __init__(self, url: Optional[str] = None, key: Optional[str] = None, secret: Optional[str] = None):
        """Initialize Schema Registry client

        Args:
            url: Schema Registry URL (optional, defaults to env var SCHEMA_REGISTRY_URL)
            key: Schema Registry API Key (optional, defaults to env var SCHEMA_REGISTRY_KEY)
            secret: Schema Registry API Secret (optional, defaults to env var SCHEMA_REGISTRY_SECRET)
        """
        self.url = url or os.getenv('SCHEMA_REGISTRY_URL')
        self.key = key or os.getenv('SCHEMA_REGISTRY_KEY')
        self.secret = secret or os.getenv('SCHEMA_REGISTRY_SECRET')

        if not all([self.url, self.key, self.secret]):
            raise ValueError(
                "Schema Registry credentials not provided. Either pass them directly "
                "or set SCHEMA_REGISTRY_URL, SCHEMA_REGISTRY_KEY, and SCHEMA_REGISTRY_SECRET "
                "environment variables."
            )

        self.config = {
            'url': self.url,
            'basic.auth.user.info': f"{self.key}:{self.secret}"
        }
        
        self.client = SchemaRegistryClient(self.config)

    def get_or_create_schema_from_pydantic(
        self,
        subject_name: str,
        model_class: Type[BaseModel],
        to_dict: Callable[[Any, SerializationContext], Dict[str, Any]]
    ) -> JSONSerializer:
        """Get existing schema or create new one from a Pydantic model

        Args:
            subject_name: Name of the schema subject
            model_class: Pydantic model class to generate schema from
            to_dict: Callable that converts your data model to a dictionary

        Returns:
            JSONSerializer configured with the schema
        """
        try:
            # Try to get the latest schema version
            schema_metadata = self.client.get_latest_version(subject_name)
            logger.info(f"Found existing schema for subject {subject_name}")
            logger.info(f"Schema ID: {schema_metadata.schema_id}")
            logger.info(f"Version: {schema_metadata.version}")
            schema = schema_metadata.schema
            
        except Exception as e:
            logger.info(f"No existing schema found for subject {subject_name}. Creating new schema.")
            
            # Generate JSON schema from Pydantic model
            schema_dict = model_class.model_json_schema()
            schema_str = json.dumps(schema_dict)

            # Register the new schema
            schema = Schema(schema_str, schema_type="JSON")
            schema_id = self.client.register_schema(
                subject_name,
                schema
            )
            logger.info(f"Registered new schema with ID: {schema_id}")

        # Create and return JSON serializer
        return JSONSerializer(
            schema.schema_str,
            self.client,
            to_dict
        )

    def get_or_create_schema(
        self, 
        subject_name: str, 
        schema_path: Path,
        schema_type: str,
        to_dict: Callable[[Any, SerializationContext], Dict[str, Any]]
    ) -> Union[JSONSerializer, AvroSerializer]:
        """Get existing schema or create new one from file

        Args:
            subject_name: Name of the schema subject
            schema_path: Path to the schema file
            schema_type: Type of schema ('JSON' or 'AVRO')
            to_dict: Callable that converts your data model to a dictionary

        Returns:
            Serializer configured with the schema (JSONSerializer or AvroSerializer)
        """
        if schema_type not in ['JSON', 'AVRO']:
            raise ValueError("schema_type must be either 'JSON' or 'AVRO'")

        try:
            # Try to get the latest schema version
            schema_metadata = self.client.get_latest_version(subject_name)
            logger.info(f"Found existing schema for subject {subject_name}")
            logger.info(f"Schema ID: {schema_metadata.schema_id}")
            logger.info(f"Version: {schema_metadata.version}")
            schema = schema_metadata.schema
            
        except Exception as e:
            logger.info(f"No existing schema found for subject {subject_name}. Creating new schema.")
            
            # Load the schema from file
            if not schema_path.exists():
                raise FileNotFoundError(f"Schema file not found at {schema_path}")

            with open(schema_path, "r") as f:
                schema_str = f.read()

            # Register the new schema
            schema = Schema(schema_str, schema_type=schema_type)
            schema_id = self.client.register_schema(
                subject_name,
                schema
            )
            logger.info(f"Registered new schema with ID: {schema_id}")

        # Create and return appropriate serializer
        if schema_type == 'JSON':
            return JSONSerializer(
                schema.schema_str,
                self.client,
                to_dict
            )
        else:  # AVRO
            return AvroSerializer(
                self.client,
                schema.schema_str,
                to_dict
            )

    def get_or_create_json_schema(
        self, 
        subject_name: str, 
        schema_path: Path,
        to_dict: Callable[[Any, SerializationContext], Dict[str, Any]]
    ) -> JSONSerializer:
        """Get existing JSON schema or create new one from file

        Args:
            subject_name: Name of the schema subject
            schema_path: Path to the JSON schema file
            to_dict: Callable that converts your data model to a dictionary

        Returns:
            JSONSerializer configured with the schema
        """
        return self.get_or_create_schema(
            subject_name=subject_name,
            schema_path=schema_path,
            schema_type='JSON',
            to_dict=to_dict
        )

    def get_or_create_avro_schema(
        self, 
        subject_name: str, 
        schema_path: Path,
        to_dict: Callable[[Any, SerializationContext], Dict[str, Any]]
    ) -> AvroSerializer:
        """Get existing Avro schema or create new one from file

        Args:
            subject_name: Name of the schema subject
            schema_path: Path to the Avro schema file
            to_dict: Callable that converts your data model to a dictionary

        Returns:
            AvroSerializer configured with the schema
        """
        return self.get_or_create_schema(
            subject_name=subject_name,
            schema_path=schema_path,
            schema_type='AVRO',
            to_dict=to_dict
        )

    def get_schema_versions(self, subject_name: str) -> list[int]:
        """Get all versions for a schema subject

        Args:
            subject_name: Name of the schema subject

        Returns:
            List of version numbers
        """
        try:
            return self.client.get_versions(subject_name)
        except Exception as e:
            logger.error(f"Error getting versions for subject {subject_name}: {e}")
            return []

    def get_schema_by_version(self, subject_name: str, version: int) -> Optional[Schema]:
        """Get a specific version of a schema

        Args:
            subject_name: Name of the schema subject
            version: Schema version number

        Returns:
            Schema object if found, None otherwise
        """
        try:
            return self.client.get_version(subject_name, version).schema
        except Exception as e:
            logger.error(f"Error getting schema version {version} for subject {subject_name}: {e}")
            return None

    def delete_schema_version(self, subject_name: str, version: int) -> bool:
        """Delete a specific version of a schema

        Args:
            subject_name: Name of the schema subject
            version: Schema version to delete

        Returns:
            True if successful, False otherwise
        """
        try:
            self.client.delete_version(subject_name, version)
            logger.info(f"Deleted version {version} of subject {subject_name}")
            return True
        except Exception as e:
            logger.error(f"Error deleting schema version {version} for subject {subject_name}: {e}")
            return False

    def delete_subject(self, subject_name: str) -> bool:
        """Delete all versions of a schema subject

        Args:
            subject_name: Name of the schema subject

        Returns:
            True if successful, False otherwise
        """
        try:
            self.client.delete_subject(subject_name)
            logger.info(f"Deleted subject {subject_name} and all its versions")
            return True
        except Exception as e:
            logger.error(f"Error deleting subject {subject_name}: {e}")
            return False

    def get_compatibility(self, subject_name: str) -> Optional[str]:
        """Get compatibility mode for a subject

        Args:
            subject_name: Name of the schema subject

        Returns:
            Compatibility mode if found, None otherwise
        """
        try:
            return self.client.get_compatibility(subject_name)
        except Exception as e:
            logger.error(f"Error getting compatibility for subject {subject_name}: {e}")
            return None

    def set_compatibility(self, subject_name: str, compatibility: str) -> bool:
        """Set compatibility mode for a subject

        Args:
            subject_name: Name of the schema subject
            compatibility: One of BACKWARD, FORWARD, FULL, NONE

        Returns:
            True if successful, False otherwise
        """
        valid_modes = ['BACKWARD', 'FORWARD', 'FULL', 'NONE']
        if compatibility not in valid_modes:
            raise ValueError(f"compatibility must be one of {valid_modes}")

        try:
            self.client.set_compatibility(subject_name, compatibility)
            logger.info(f"Set compatibility mode to {compatibility} for subject {subject_name}")
            return True
        except Exception as e:
            logger.error(f"Error setting compatibility for subject {subject_name}: {e}")
            return False