"""
Kafka AdminClient helpers for listing cluster topics.

Env vars (typically from ~/.confluent/.env):
  KAFKA_BOOTSTRAP_SERVERS, KAFKA_API_KEY, KAFKA_API_SECRET
  KAFKA_SECURITY_PROTOCOL, KAFKA_SASL_MECHANISM (optional)
"""

from __future__ import annotations

import os

from confluent_kafka.admin import AdminClient

INTERNAL_TOPIC_NAMES = frozenset({"__consumer_offsets"})


def _resolve_kafka_security() -> tuple[str, str | None]:
    """Return (security.protocol, sasl.mechanisms) from env, with Confluent Cloud defaults."""
    user = os.environ.get("KAFKA_API_KEY", "")
    protocol = os.environ.get("KAFKA_SECURITY_PROTOCOL", "PLAINTEXT")
    mechanism = os.environ.get("KAFKA_SASL_MECHANISM", "SASL")
    brokers = os.environ.get("KAFKA_BOOTSTRAP_SERVERS", "")

    if not user:
        return protocol, None

    if mechanism in ("SASL_SSL", "SASL_PLAINTEXT"):
        if not os.environ.get("KAFKA_SECURITY_PROTOCOL"):
            protocol = mechanism
        mechanism = "PLAIN"
    elif mechanism in ("", "SASL"):
        mechanism = "PLAIN"

    if protocol in ("", "PLAINTEXT") and (user or "confluent.cloud" in brokers):
        protocol = "SASL_SSL"

    return protocol, mechanism


def kafka_client_config() -> dict[str, str]:
    """Shared broker/auth settings for admin clients."""
    user = os.environ.get("KAFKA_API_KEY", "")
    password = os.environ.get("KAFKA_API_SECRET", "")
    brokers = os.environ.get("KAFKA_BOOTSTRAP_SERVERS", "")
    if not brokers:
        raise ValueError("Set KAFKA_BOOTSTRAP_SERVERS")

    security_protocol, sasl_mechanism = _resolve_kafka_security()
    options: dict[str, str] = {"bootstrap.servers": brokers}
    if user and sasl_mechanism:
        options.update(
            {
                "security.protocol": security_protocol,
                "sasl.mechanisms": sasl_mechanism,
                "sasl.username": user,
                "sasl.password": password,
            }
        )
    return options


def is_internal_topic(name: str) -> bool:
    """True for Kafka/Confluent internal topics that should not be dropped by default."""
    return name in INTERNAL_TOPIC_NAMES or name.startswith("_")


def list_topics(*, exclude_internal: bool = True, timeout: float = 15) -> list[str]:
    """List topic names in the Kafka cluster, sorted alphabetically."""
    admin = AdminClient(kafka_client_config())
    try:
        metadata = admin.list_topics(timeout=timeout)
    except Exception as exc:
        config = kafka_client_config()
        protocol = config.get("security.protocol", "PLAINTEXT")
        raise RuntimeError(
            f"Failed to connect to Kafka at {config.get('bootstrap.servers')!r} "
            f"(security.protocol={protocol}). For Confluent Cloud use "
            "KAFKA_SECURITY_PROTOCOL=SASL_SSL and KAFKA_SASL_MECHANISM=PLAIN."
        ) from exc

    names: list[str] = []
    for name, topic_meta in metadata.topics.items():
        if topic_meta.error is not None:
            continue
        if exclude_internal and is_internal_topic(name):
            continue
        names.append(name)
    return sorted(names)
