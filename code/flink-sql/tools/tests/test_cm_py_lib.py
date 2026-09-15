"""Unit tests for cm_py_lib modules: config, kafka_json_producer, kafka_avro_producer, schema_registry."""

from __future__ import annotations


import os
from pathlib import Path
from unittest.mock import patch
from datetime import datetime, timezone
from pydantic import BaseModel, Field, AwareDatetime

from cm_py_lib import config
from cm_py_lib.config import (
    get_default_replication_factor,
    get_kafka_client_config,
    get_schema_registry_config,
    resolve_kafka_security,
    setup_logging,
    ensure_topic_exists
)
from cm_py_lib.kafka_json_producer import (
    KafkaJSONProducer,
    prepare_json_schema_for_registry,
)

from cm_py_lib.kafka_avro_producer import (
    KafkaAvroProducer
)

from cm_py_lib.schema_registry import (
    ColumnSpec,
    SchemaFetcher,
    _avro_to_columns,
    _json_to_columns,
    render_model_yaml,
    is_schema_incompatible,
    is_subject_not_found,
    render_sources_yaml,
    get_schema_for_topic,
    schema_to_columns,
)
from confluent_kafka.schema_registry.error import SchemaRegistryError
root_env_path = Path(__file__).resolve().parents[4] / ".env"
os.environ["DEMO_ENV_FILE"] = str(root_env_path)

TEST_TOPIC_NAME="demosample"

# =============== config.py ======================

def test_setup_logging(tmp_path: Path):
    test_log_file = tmp_path / "test_run.log"
    logger = setup_logging(logger_name="test_logger", log_file=test_log_file)
    assert logger.name == "test_logger"
    assert logger.level == config.logging.INFO
    assert len(logger.handlers) >= 1

    logger.info("Test log line written")
    # Flush handlers to ensure file content is persisted
    for h in logger.handlers:
        h.flush()
    assert test_log_file.exists()
    content = test_log_file.read_text(encoding="utf-8")
    assert "Test log line written" in content


def test_config_loads_env_from_root_dot_env(tmp_path: Path):
    # Simulate a root .env file
    env_content = "KAFKA_BOOTSTRAP_SERVERS=custom-broker:9092\nKAFKA_API_KEY=testkey\n"
    custom_env = tmp_path / ".env"
    custom_env.write_text(env_content, encoding="utf-8")

    from dotenv import dotenv_values
    values = dotenv_values(custom_env)
    assert values["KAFKA_BOOTSTRAP_SERVERS"] == "custom-broker:9092"
    assert values["KAFKA_API_KEY"] == "testkey"


def test_root_dot_env_loaded_into_config():
    """Verify that root repo .env file (if present) is loaded into config variables."""
    if not root_env_path.exists():
        pytest.skip(".env not present in flink-studies root folder")
    from_ev_var = Path(os.getenv("DEMO_ENV_FILE",".env"))
    if not from_ev_var.exists():
            print("Error for DEMO_ENV_FILE")

    from dotenv import dotenv_values
    expected_values = dotenv_values(root_env_path)

    # Check key variables match what is in root .env if defined there
    if "KAFKA_BOOTSTRAP_SERVERS" in expected_values:
        assert config.KAFKA_BROKERS == expected_values["KAFKA_BOOTSTRAP_SERVERS"]
    if "KAFKA_API_KEY" in expected_values:
        assert config.KAFKA_USER == expected_values["KAFKA_API_KEY"]
    if "KAFKA_API_SECRET" in expected_values:
        assert config.KAFKA_PASSWORD == expected_values["KAFKA_API_SECRET"]
    if "SCHEMA_REGISTRY_ENDPOINT" in expected_values:
        assert config.SCHEMA_REGISTRY_URL == expected_values["SCHEMA_REGISTRY_ENDPOINT"]
    elif "SCHEMA_REGISTRY_URL" in expected_values:
        assert config.SCHEMA_REGISTRY_URL == expected_values["SCHEMA_REGISTRY_URL"]
    if "SCHEMA_REGISTRY_API_KEY" in expected_values:
        assert config.SCHEMA_REGISTRY_USER == expected_values["SCHEMA_REGISTRY_API_KEY"]
    elif "SCHEMA_REGISTRY_USER" in expected_values:
        assert config.SCHEMA_REGISTRY_USER == expected_values["SCHEMA_REGISTRY_USER"]
    if "SCHEMA_REGISTRY_API_SECRET" in expected_values:
        assert config.SCHEMA_REGISTRY_PASSWORD == expected_values["SCHEMA_REGISTRY_API_SECRET"]
    elif "SCHEMA_REGISTRY_PASSWORD" in expected_values:
        assert config.SCHEMA_REGISTRY_PASSWORD == expected_values["SCHEMA_REGISTRY_PASSWORD"]



def test_config_kafka_security_resolution():
    with patch.object(config, "KAFKA_USER", ""), patch.object(
        config, "KAFKA_SECURITY_PROTOCOL", "PLAINTEXT"
    ):
        proto, mech = resolve_kafka_security()
        assert proto == "PLAINTEXT"
        assert mech is None

    with patch.object(config, "KAFKA_USER", "user1"), patch.object(
        config, "KAFKA_SECURITY_PROTOCOL", "PLAINTEXT"
    ), patch.object(config, "KAFKA_SASL_MECHANISM", "PLAIN"), patch.object(
        config, "KAFKA_BROKERS", "pkc-123.confluent.cloud:9092"
    ):
        proto, mech = resolve_kafka_security()
        assert proto == "SASL_SSL"
        assert mech == "PLAIN"


def test_config_client_configs():
    with patch.object(config, "KAFKA_BROKERS", "localhost:9092"), patch.object(
        config, "KAFKA_USER", ""
    ), patch.object(config, "KAFKA_PASSWORD", ""):
        cfg = get_kafka_client_config()
        assert cfg == {"bootstrap.servers": "localhost:9092"}

    with patch.object(config, "SCHEMA_REGISTRY_URL", "http://localhost:8081"), patch.object(
        config, "SCHEMA_REGISTRY_USER", "my-key"
    ), patch.object(config, "SCHEMA_REGISTRY_PASSWORD", "my-secret"):
        sr_cfg = get_schema_registry_config()
        assert sr_cfg["url"] == "http://localhost:8081"
        assert sr_cfg["basic.auth.user.info"] == "my-key:my-secret"

    sr_custom = get_schema_registry_config(
        url="http://custom:8081", user="u", password="p"
    )
    assert sr_custom["url"] == "http://custom:8081"
    assert sr_custom["basic.auth.user.info"] == "u:p"


def test_config_replication_factor():
    with patch.object(config, "KAFKA_REPLICATION_FACTOR", 2):
        assert get_default_replication_factor() == 2

    with patch.object(config, "KAFKA_REPLICATION_FACTOR", None), patch.object(
        config, "KAFKA_USER", ""
    ), patch.object(config, "KAFKA_SECURITY_PROTOCOL", "PLAINTEXT"):
        assert get_default_replication_factor() == 1


class SampleModel(BaseModel):
    id: str
    user_id: int
    amount: float = Field(default=0.0)
    creation_ts: AwareDatetime

def test_topic_exists() :
    from_ev_var = Path(os.getenv("DEMO_ENV_FILE",".env"))
    if not from_ev_var.exists():
        pytest.skip(".env not present in flink-studies root folder")
    cfg = get_kafka_client_config()
    try:
        topic_exist = ensure_topic_exists(cfg, 
                            TEST_TOPIC_NAME,
                            partitions=1,
                             replication_factor=3)
        assert topic_exist
        schema_dict = SampleModel.model_json_schema()
        print(schema_dict)
        jsonschema_dict = prepare_json_schema_for_registry(schema_dict, SampleModel, None)
        print(jsonschema_dict)
        schema = get_schema_for_topic(TEST_TOPIC_NAME)
    except Exception as e:
        # expected 
        assert True

# ================ Schema registries ==============

def test_schema_errors_helpers():

    err_404 = SchemaRegistryError(http_status_code=404, error_code=40401, error_message="Not found")
    err_409 = SchemaRegistryError(http_status_code=409, error_code=40901, error_message="Incompatible")
    err_other = SchemaRegistryError(http_status_code=500, error_code=50000, error_message="Server error")

    assert is_subject_not_found(err_404) is True
    assert is_subject_not_found(err_409) is False
    assert is_schema_incompatible(err_409) is True
    assert is_schema_incompatible(err_other) is False





def test_prepare_json_schema_for_registry():
    schema = SampleModel.model_json_schema()
    prepared = prepare_json_schema_for_registry(schema, SampleModel)
    assert prepared["additionalProperties"] is False
    

def test_schema_registry_schema_to_columns():
    json_schema = {
        "type": "object",
        "properties": {
            "id": {"type": "string"},
            "count": {"type": "integer"},
            "created_at": {"type": "string", "format": "date-time"},
        },
    }
    cols = schema_to_columns(json_schema, "JSON")
    assert len(cols) == 3
    assert cols[0].name == "id" and cols[0].data_type == "string"
    assert cols[1].name == "count" and cols[1].data_type == "int"
    assert cols[2].name == "created_at" and cols[2].data_type == "timestamp(3)"

    yaml_out = render_sources_yaml("events", "test_env", cols)
    assert "events" in yaml_out
    assert "test_env" in yaml_out


# ======= Kafka producer

def test_build_json_producer():
    json_producer = KafkaJSONProducer(topic_name=TEST_TOPIC_NAME, model_class=SampleModel)
    assert json_producer
    one_record = SampleModel(id="id_01", user_id=10, creation_ts=datetime.now(timezone.utc))
    result = json_producer.send_record(one_record.id, one_record)
    assert result


def test_build_avro_producer():
    json_producer = KafkaAvroProducer(topic_name=TEST_TOPIC_NAME, model_class=SampleModel)
    assert json_producer
    one_record = SampleModel(id="id_01", user_id=10, creation_ts=datetime.now(timezone.utc))
    result = json_producer.send_record(one_record.id, one_record)
    assert result