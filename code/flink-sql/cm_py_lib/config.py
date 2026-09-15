"""

* Centralize all Kafka environment variables (KAFKA_BOOTSTRAP_SERVERS, KAFKA_API_KEY, KAFKA_API_SECRET, KAFKA_SASL_MECHANISM, KAFKA_SECURITY_PROTOCOL, KAFKA_TOPIC, KAFKA_PARTITIONS, KAFKA_REPLICATION_FACTOR).
* Centralize all Schema Registry environment variables (SCHEMA_REGISTRY_ENDPOINT / SCHEMA_REGISTRY_URL, SCHEMA_REGISTRY_API_KEY / SCHEMA_REGISTRY_USER, SCHEMA_REGISTRY_API_SECRET / SCHEMA_REGISTRY_PASSWORD).
*  configuration helpers:
    resolve_kafka_security()
    get_kafka_client_config()
    get_default_replication_factor()
    get_schema_registry_config()

* Set structured logging setup with LOGGER and setup_logging().
"""

from __future__ import annotations
import logging
import os
from pathlib import Path
from confluent_kafka.admin import AdminClient, NewTopic

try:
    from dotenv import find_dotenv, load_dotenv

    _env_file = os.getenv("DEMO_ENV_FILE")
    if _env_file:
        load_dotenv(_env_file)
    else:
        # Search upward from current file location or cwd for .env
        _discovered_env = find_dotenv(usecwd=True)
        if not _discovered_env:
            _discovered_env = find_dotenv(filename=str(Path(__file__).resolve().parents[3] / ".env"))
        if _discovered_env:
            load_dotenv(_discovered_env)
        else:
            load_dotenv()
except ImportError:
    pass


# ── Logging Configuration ───────────────────────────────────────────────────

_LOG_FORMAT = "%(asctime)s %(levelname)s [%(name)s] %(filename)s:%(lineno)d %(message)s"


def setup_logging(logger_name: str = "kma", log_file: str | Path = "logs/kma.log") -> logging.Logger:
    """Set up and return a file + stream logger."""
    _logger = logging.getLogger(logger_name)
    _logger.setLevel(logging.INFO)
    if not _logger.handlers:
        log_path = Path(log_file)
        log_path.parent.mkdir(parents=True, exist_ok=True)
        handler = logging.FileHandler(log_path)
        handler.setFormatter(logging.Formatter(_LOG_FORMAT))
        _logger.addHandler(handler)
    return _logger


LOGGER = setup_logging()


# ── Kafka Configuration ──────────────────────────────────────────────────────

KAFKA_BROKERS: str = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "localhost:9094")
KAFKA_USER: str = os.getenv("KAFKA_API_KEY", "")
KAFKA_PASSWORD: str = os.getenv("KAFKA_API_SECRET", "")
KAFKA_SASL_MECHANISM: str = os.getenv("KAFKA_SASL_MECHANISM", "SASL")
KAFKA_SECURITY_PROTOCOL: str = os.getenv("KAFKA_SECURITY_PROTOCOL", "PLAINTEXT")
DEFAULT_TOPIC: str = os.getenv("KAFKA_TOPIC", "raw-rides")
KAFKA_PARTITIONS: int = int(os.getenv("KAFKA_PARTITIONS", "1"))

_rf_env = os.getenv("KAFKA_REPLICATION_FACTOR")
KAFKA_REPLICATION_FACTOR: Optional[int] = int(_rf_env) if _rf_env is not None else None


# ── Schema Registry Configuration ────────────────────────────────────────────

SCHEMA_REGISTRY_URL: str = os.getenv(
    "SCHEMA_REGISTRY_ENDPOINT",
    os.getenv("SCHEMA_REGISTRY_URL", "http://localhost:8081"),
)
SCHEMA_REGISTRY_USER: str = os.getenv(
    "SCHEMA_REGISTRY_API_KEY",
    os.getenv("SCHEMA_REGISTRY_USER", ""),
)
SCHEMA_REGISTRY_PASSWORD: str = os.getenv(
    "SCHEMA_REGISTRY_API_SECRET",
    os.getenv("SCHEMA_REGISTRY_PASSWORD", ""),
)


# ── Helper Functions ─────────────────────────────────────────────────────────

def resolve_kafka_security() -> tuple[str, str | None]:
    """Return (security.protocol, sasl.mechanisms) from env, with Confluent Cloud defaults."""
    if not KAFKA_USER:
        return KAFKA_SECURITY_PROTOCOL, None

    protocol = KAFKA_SECURITY_PROTOCOL
    mechanism = KAFKA_SASL_MECHANISM

    # Common mistake: security protocol name placed in KAFKA_SASL_MECHANISM.
    if mechanism in ("SASL_SSL", "SASL_PLAINTEXT"):
        if not os.getenv("KAFKA_SECURITY_PROTOCOL"):
            protocol = mechanism
        mechanism = "PLAIN"
    elif mechanism in ("", "SASL"):
        mechanism = "PLAIN"

    # Confluent Cloud (and most hosted clusters) require SASL_SSL when API keys are set.
    if protocol in ("", "PLAINTEXT") and (
        KAFKA_USER or "confluent.cloud" in KAFKA_BROKERS
    ):
        protocol = "SASL_SSL"

    return protocol, mechanism


def get_kafka_client_config() -> dict[str, str]:
    """Shared broker/auth settings for producer and admin clients."""
    security_protocol, sasl_mechanism = resolve_kafka_security()
    options: dict[str, str] = {
        "bootstrap.servers": KAFKA_BROKERS,
    }
    if KAFKA_USER and sasl_mechanism:
        options.update(
            {
                "security.protocol": security_protocol,
                "sasl.mechanisms": sasl_mechanism,
                "sasl.username": KAFKA_USER,
                "sasl.password": KAFKA_PASSWORD,
            }
        )
    return options


def get_default_replication_factor() -> int:
    """Return configured replication factor, or default: 1 for local PLAINTEXT, 3 for cloud."""
    if KAFKA_REPLICATION_FACTOR is not None:
        return KAFKA_REPLICATION_FACTOR
    protocol, _ = resolve_kafka_security()
    return 1 if protocol == "PLAINTEXT" else 3


def get_schema_registry_config(
    url: str | None = None,
    user: str | None = None,
    password: str | None = None,
) -> dict[str, str]:
    """Build configuration dict for confluent_kafka SchemaRegistryClient."""
    effective_url = url or SCHEMA_REGISTRY_URL
    effective_user = user if user is not None else SCHEMA_REGISTRY_USER
    effective_password = password if password is not None else SCHEMA_REGISTRY_PASSWORD

    conf: dict[str, str] = {"url": effective_url}
    if effective_user:
        conf["basic.auth.user.info"] = f"{effective_user}:{effective_password}"
    return conf


def ensure_topic_exists(
    kafka_config: dict[str, str],
    topic_name: str,
    partitions: int = KAFKA_PARTITIONS,
    replication_factor: int | None = None,
) -> bool:
    """Create the Kafka topic when it does not exist."""
    admin = AdminClient(kafka_config)
    try:
        metadata = admin.list_topics(timeout=15)
    except Exception as exc:
        protocol = kafka_config.get('security.protocol', 'PLAINTEXT')
        raise RuntimeError(
            f"Failed to connect to Kafka at {kafka_config.get('bootstrap.servers')!r} "
            f"(security.protocol={protocol}). For Confluent Cloud use "
            "KAFKA_SECURITY_PROTOCOL=SASL_SSL and KAFKA_SASL_MECHANISM=PLAIN."
        ) from exc
    if topic_name in metadata.topics and metadata.topics[topic_name].error is None:
        return True

    rf = replication_factor if replication_factor is not None else get_default_replication_factor()
    futures = admin.create_topics(
        [NewTopic(topic_name, num_partitions=partitions, replication_factor=rf)]
    )
    for name, future in futures.items():
        try:
            future.result(timeout=30)
            print(f"Created Kafka topic '{name}'.")
        except Exception as exc:
            if "TOPIC_ALREADY_EXISTS" in str(exc):
                return True
            raise RuntimeError(f"Failed to create topic '{name}': {exc}") from exc
    return True