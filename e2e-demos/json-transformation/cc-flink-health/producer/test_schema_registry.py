#!/usr/bin/env python3
import pytest
from pathlib import Path
from schema_registry import SchemaRegistryManager
from models import PersonMDM
from confluent_kafka.serialization import SerializationContext, MessageField
from typing import Dict, Any
from dotenv import load_dotenv
import json
import os
import uuid
from datetime import datetime

# Load environment variables from .env file
env_path = Path(__file__).parent / '.env'
if env_path.exists():
    load_dotenv(env_path)
else:
    print(f"Warning: .env file not found at {env_path}")

# Test configuration
TEST_JSON_SUBJECT = f"test-json-j9r-value"
TEST_AVRO_SUBJECT = f"test-avro-j9r-value"

@pytest.fixture(scope="session")
def schema_registry_config(request):
    """Get Schema Registry configuration from environment or pytest options"""
    # Try to get from environment first (loaded from .env)
    url = os.getenv('SCHEMA_REGISTRY_URL')
    key = os.getenv('SCHEMA_REGISTRY_KEY')
    secret = os.getenv('SCHEMA_REGISTRY_SECRET')

    # If not in environment, check pytest command line options
    if not all([url, key, secret]):
        url = request.config.getoption("--sr-url")
        key = request.config.getoption("--sr-key")
        secret = request.config.getoption("--sr-secret")

    if not all([url, key, secret]):
        pytest.skip(
            "Schema Registry credentials not provided. Either:\n"
            "1. Create a .env file with SCHEMA_REGISTRY_URL, SCHEMA_REGISTRY_KEY, and SCHEMA_REGISTRY_SECRET\n"
            "2. Set environment variables directly\n"
            "3. Use pytest options: --sr-url, --sr-key, --sr-secret"
        )

    return {
        'url': url,
        'key': key,
        'secret': secret
    }

def pytest_addoption(parser):
    """Add Schema Registry options to pytest"""
    parser.addoption("--sr-url", action="store", help="Schema Registry URL")
    parser.addoption("--sr-key", action="store", help="Schema Registry API Key")
    parser.addoption("--sr-secret", action="store", help="Schema Registry API Secret")

@pytest.fixture(scope="session")
def schema_registry(schema_registry_config):
    """Create a SchemaRegistryManager instance"""
    manager = SchemaRegistryManager(
        url=schema_registry_config['url'],
        key=schema_registry_config['key'],
        secret=schema_registry_config['secret']
    )
    yield manager

@pytest.fixture(scope="session")
def avro_schema_path(tmp_path_factory):
    """Create a temporary Avro schema file"""
    tmp_path = tmp_path_factory.mktemp("schemas")
    schema_content = {
        "type": "record",
        "name": "TestRecord",
        "namespace": "com.example.test",
        "fields": [
            {"name": "id", "type": "string"},
            {"name": "name", "type": "string"},
            {"name": "age", "type": "int"},
            {
                "name": "address",
                "type": {
                    "type": "record",
                    "name": "Address",
                    "fields": [
                        {"name": "street", "type": "string"},
                        {"name": "city", "type": "string"},
                        {"name": "country", "type": "string"}
                    ]
                }
            }
        ]
    }
    
    schema_file = tmp_path / "test_schema.avsc"
    schema_file.write_text(json.dumps(schema_content))
    return schema_file

def test_json_schema_lifecycle(schema_registry):
    """Test the complete lifecycle of a JSON schema:
    - Creation from Pydantic model
    - Verification of existence
    - Schema compatibility
    - Deletion
    """
    try:
        # Test data conversion function
        def to_dict(obj: Any, ctx: SerializationContext) -> Dict[str, Any]:
            if isinstance(obj, dict):
                return obj
            return json.loads(json.dumps(obj.model_dump()))

        # Create schema from Pydantic model
        serializer = schema_registry.get_or_create_schema_from_pydantic(
            subject_name=TEST_JSON_SUBJECT,
            model_class=PersonMDM,
            to_dict=to_dict
        )
        assert serializer is not None, "Failed to create JSON serializer"

        # Verify schema exists
        versions = schema_registry.get_schema_versions(TEST_JSON_SUBJECT)
        assert len(versions) > 0, "Schema versions not found"
        assert 1 in versions, "Version 1 not found"

        # Get and verify schema
        schema = schema_registry.get_schema_by_version(TEST_JSON_SUBJECT, 1)
        assert schema is not None, "Failed to retrieve schema"
        assert "PersonMDM" in schema.schema_str, "Schema content mismatch"

        # Test compatibility mode
        success = schema_registry.set_compatibility(TEST_JSON_SUBJECT, "FORWARD")
        print(f"Success: {success}")
        assert success, "Failed to set compatibility mode"

        compatibility = schema_registry.get_compatibility(TEST_JSON_SUBJECT)
        assert compatibility == "FORWARD", "Compatibility mode mismatch"

    finally:
        # Cleanup
        schema_registry.delete_subject(TEST_JSON_SUBJECT)
        versions = schema_registry.get_schema_versions(TEST_JSON_SUBJECT)
        assert len(versions) == 0, "Failed to delete schema"

def test_avro_schema_lifecycle(schema_registry, avro_schema_path):
    """Test the complete lifecycle of an Avro schema:
    - Creation from file
    - Verification of existence
    - Schema compatibility
    - Deletion
    """
    try:
        # Test data conversion function
        def to_dict(obj: Dict[str, Any], ctx: SerializationContext) -> Dict[str, Any]:
            return obj

        # Create schema from file
        serializer = schema_registry.get_or_create_avro_schema(
            subject_name=TEST_AVRO_SUBJECT,
            schema_path=avro_schema_path,
            to_dict=to_dict
        )
        assert serializer is not None, "Failed to create Avro serializer"

        # Verify schema exists
        versions = schema_registry.get_schema_versions(TEST_AVRO_SUBJECT)
        assert len(versions) > 0, "Schema versions not found"
        assert 1 in versions, "Version 1 not found"

        # Get and verify schema
        schema = schema_registry.get_schema_by_version(TEST_AVRO_SUBJECT, 1)
        assert schema is not None, "Failed to retrieve schema"
        assert "TestRecord" in schema.schema_str, "Schema content mismatch"

        # Test compatibility mode
        success = schema_registry.set_compatibility(TEST_AVRO_SUBJECT, "FULL")
        assert success, "Failed to set compatibility mode"

        compatibility = schema_registry.get_compatibility(TEST_AVRO_SUBJECT)
        assert compatibility == "FULL", "Compatibility mode mismatch"

        # Test schema deletion by version
        success = schema_registry.delete_schema_version(TEST_AVRO_SUBJECT, 1)
        assert success, "Failed to delete schema version"

    finally:
        # Cleanup
        schema_registry.delete_subject(TEST_AVRO_SUBJECT)
        versions = schema_registry.get_schema_versions(TEST_AVRO_SUBJECT)
        assert len(versions) == 0, "Failed to delete schema"

def test_schema_error_handling(schema_registry, tmp_path):
    """Test error handling in schema registry operations"""
    
    # Test non-existent schema file
    non_existent_path = tmp_path / "non_existent.avsc"
    with pytest.raises(FileNotFoundError):
        schema_registry.get_or_create_avro_schema(
            subject_name="test-error",
            schema_path=non_existent_path,
            to_dict=lambda x, ctx: x
        )

    # Test invalid compatibility mode
    with pytest.raises(ValueError):
        schema_registry.set_compatibility(TEST_AVRO_SUBJECT, "INVALID_MODE")

    # Test getting non-existent schema version
    schema = schema_registry.get_schema_by_version("non-existent-subject", 1)
    assert schema is None, "Should return None for non-existent schema"

    # Test deleting non-existent schema version
    success = schema_registry.delete_schema_version("non-existent-subject", 1)
    assert not success, "Should return False for non-existent schema version"

if __name__ == "__main__":
    pytest.main([__file__, "-v"])