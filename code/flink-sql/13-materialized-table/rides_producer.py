"""
Produce ride records to Kafka for materialized-table demos.

Usage:
```sh
# 200 records with Ride schema (default)
uv run python rides_producer.py

# 50 records with Ride2 schema (adds car_type: S | L | XL, default S)
uv run python rides_producer.py --count 50 --schema ride2
```

Ride2 supports schema-evolution demonstrations: register a new JSON schema version with
the extra ``car_type`` field after an initial run with ``--schema ride``.

Dependencies:
- confluent-kafka[schema-registry]>=2.3.0
- pydantic>=2.0.0
- jsonschema>=4.0.0
"""

import argparse
import os
import random
import time
import uuid
from datetime import datetime, timedelta
from typing import Literal, Type

from cm_py_lib.kafka_json_producer import KafkaJSONProducer
from pydantic import BaseModel, Field

DEFAULT_TOPIC = os.getenv('KAFKA_TOPIC', 'raw_rides')
LOCATIONS = [
    'Financial_district',
    'Castro',
    'North_beach',
    'South_market',
    'Union_square',
]
CAR_TYPES = ('S', 'L', 'XL')


class Ride(BaseModel):
    ride_id: str
    driver_id: str
    pickup_location: str
    dropoff_location: str
    pickup_time: str
    dropoff_time: str
    distance: float
    fare: float
    payment_type: str
    rating: float


class Ride2(BaseModel):
    ride_id: str
    driver_id: str
    car_type: Literal['S', 'L', 'XL'] = Field(default='S')
    pickup_location: str
    dropoff_location: str
    pickup_time: str
    dropoff_time: str
    distance: float
    fare: float
    payment_type: str
    rating: float


def _pick_dropoff(pickup: str) -> str:
    return random.choice([loc for loc in LOCATIONS if loc != pickup])


def _base_ride_fields() -> dict:
    pickup = random.choice(LOCATIONS)
    return {
        'ride_id': str(uuid.uuid4()),
        'driver_id': f'Driver_{random.randint(1, 50)}',
        'pickup_location': pickup,
        'dropoff_location': _pick_dropoff(pickup),
        'pickup_time': datetime.now().isoformat(),
        'dropoff_time': (datetime.now() + timedelta(hours=random.randint(1, 20))).isoformat(),
        'distance': round(random.uniform(1, 20), 2),
        'fare': round(random.uniform(1, 80), 2),
        'payment_type': random.choice(
            ['Credit Card', 'Debit Card', 'Cash', 'Apple Pay', 'Google Pay']
        ),
        'rating': round(random.uniform(1, 5), 0),
    }


def generate_ride_record(_i: int) -> Ride:
    return Ride(**_base_ride_fields())


def generate_ride2_record(_i: int) -> Ride2:
    return Ride2(**_base_ride_fields(), car_type=random.choice(CAR_TYPES))


SCHEMA_CHOICES: dict[str, tuple[Type[BaseModel], object]] = {
    'ride': (Ride, generate_ride_record),
    'ride2': (Ride2, generate_ride2_record),
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description='Produce ride records to Kafka')
    parser.add_argument(
        '--count', '-c',
        type=int,
        default=200,
        help='Number of records to send (default: 200)',
    )
    parser.add_argument(
        '--schema', '-s',
        choices=sorted(SCHEMA_CHOICES),
        default='ride',
        help='Record schema: ride (default) or ride2 (adds car_type S|L|XL)',
    )
    parser.add_argument(
        '--topic',
        default=DEFAULT_TOPIC,
        help=f'Kafka topic (default: {DEFAULT_TOPIC})',
    )
    parser.add_argument(
        '--interval',
        type=float,
        default=1.0,
        help='Seconds between records (default: 1.0)',
    )
    return parser.parse_args()


def main():
    args = parse_args()
    if args.count <= 0:
        raise ValueError('--count must be greater than 0')

    model_class, generate = SCHEMA_CHOICES[args.schema]

    print(f"Starting to produce {args.count} {args.schema} records to topic: {args.topic}")
    producer = KafkaJSONProducer(
        topic_name=args.topic,
        use_schema_registry=True,
        model_class=model_class,
    )
    for i in range(args.count):
        record = generate(i)
        print(f"Sending record {i + 1}/{args.count}: {record}")
        message_key = record.ride_id
        success = producer.send_record(message_key, record)
        if success:
            print(f"Record {i + 1} sent successfully")
        else:
            print(f"Record {i + 1} failed to send")
            break
        if i < args.count - 1 and args.interval > 0:
            time.sleep(args.interval)
    producer.flush_and_close()


if __name__ == '__main__':
    main()
