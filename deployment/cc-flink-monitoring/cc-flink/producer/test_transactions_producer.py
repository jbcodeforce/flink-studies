from __future__ import annotations

import random
import sys
import unittest
from datetime import UTC, datetime
from decimal import Decimal
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parent))
from transactions_producer import (
    ProducerPlan,
    build_kafka_config,
    build_schema_registry_config,
    build_transactions,
    env_value,
    transaction_to_avro,
)


class TransactionsProducerTests(unittest.TestCase):
    def test_build_transactions_has_progressive_timestamps(self) -> None:
        plan = ProducerPlan(users=2, days=2, tx_per_user_per_day=2)
        records = list(build_transactions(plan, random.Random(1)))
        timestamps = [row["ts"] for row in records]

        self.assertEqual(len(records), 8)
        self.assertEqual(timestamps, sorted(timestamps))
        self.assertLess(timestamps[0], timestamps[-1])

    def test_build_transactions_matches_expected_shape(self) -> None:
        plan = ProducerPlan(users=2, days=1, tx_per_user_per_day=1)
        records = list(build_transactions(plan, random.Random(7)))

        self.assertEqual(len(records), 2)
        self.assertSetEqual(
            set(records[0].keys()),
            {"transaction_id", "user_id", "amount", "ts"},
        )
        self.assertEqual(records[0]["user_id"], "user_001")
        self.assertEqual(records[1]["user_id"], "user_002")
        self.assertIsInstance(records[0]["amount"], Decimal)

    @patch.dict(
        "os.environ",
        {
            "BOOTSTRAP_SERVERS": "pkc-example.aws.confluent.cloud:9092",
            "KAFKA_BOOTSTRAP_SERVERS": "${BOOTSTRAP_SERVERS}",
            "KAFKA_API_KEY": "kafka-key",
            "KAFKA_API_SECRET": "kafka-secret",
        },
        clear=True,
    )
    def test_build_kafka_config_from_env(self) -> None:
        config = build_kafka_config()
        self.assertEqual(config["bootstrap.servers"], "pkc-example.aws.confluent.cloud:9092")
        self.assertEqual(config["sasl.username"], "kafka-key")
        self.assertEqual(config["security.protocol"], "SASL_SSL")

    @patch.dict(
        "os.environ",
        {
            "SCHEMA_REGISTRY_ENDPOINT": "https://psrc-example.confluent.cloud",
            "SCHEMA_REGISTRY_API_KEY": "sr-key",
            "SCHEMA_REGISTRY_API_SECRET": "sr-secret",
        },
        clear=True,
    )
    def test_build_schema_registry_config_from_env(self) -> None:
        config = build_schema_registry_config()
        self.assertEqual(config["url"], "https://psrc-example.confluent.cloud")
        self.assertEqual(config["basic.auth.user.info"], "sr-key:sr-secret")

    @patch.dict("os.environ", {"BOOTSTRAP_SERVERS": '"pkc-quoted.example:9092"'}, clear=True)
    def test_env_value_strips_quotes(self) -> None:
        self.assertEqual(env_value("BOOTSTRAP_SERVERS"), "pkc-quoted.example:9092")

    def test_transaction_to_avro_converts_timestamp(self) -> None:
        ts = datetime(2025, 6, 1, 12, 0, 0, tzinfo=UTC)
        payload = transaction_to_avro(
            {
                "transaction_id": "tx-1",
                "user_id": "user_001",
                "amount": Decimal("12.34"),
                "ts": ts,
            },
            None,
        )
        self.assertEqual(payload["ts"], int(ts.timestamp() * 1000))
        self.assertEqual(payload["amount"], Decimal("12.34"))


if __name__ == "__main__":
    unittest.main()
