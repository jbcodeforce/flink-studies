#!/usr/bin/env python3
from datetime import datetime
from typing import Optional, List, Dict
from pydantic import BaseModel, Field
import random
import uuid
import json

class Headers(BaseModel):
    """Headers for the member record"""
    op: str = Field(description="Operation type (INSERT, UPDATE, DELETE)")
    ts_ms: int = Field(description="Timestamp in milliseconds")
    transaction_id: str = Field(description="Unique transaction identifier")

class SystemOfRecord(BaseModel):
    """System of record information"""
    sourceSystem: str = Field(description="Source system identifier")
    sourceEntity: str = Field(description="Source entity name")
    sourcePublishedDate: str = Field(description="Date when record was published")
    sourceCorrelationReference: str = Field(description="Correlation reference")
    entityKey: str = Field(description="Unique entity identifier")

class PersonMDM(BaseModel):
    """Person MDM record following Flink table schema"""
    headers: Headers
    data: str = Field(description="Main data payload")
    beforeData: Optional[str] = Field(default=None, description="Previous state of data for updates")
    systemOfRecord: SystemOfRecord

    @classmethod
    def create_from_data(
        cls,
        data: Dict,
        operation: str = "INSERT",
        source_system: str = "MEMBER_MDM",
        source_entity: str = "PERSON"
    ) -> "PersonMDM":
        """Factory method to create a PersonMDM instance from data

        Args:
            data: Dictionary containing member data
            operation: Operation type (INSERT, UPDATE, DELETE)
            source_system: Source system identifier
            source_entity: Source entity name

        Returns:
            PersonMDM instance
        """
        current_ts = int(datetime.now().timestamp() * 1000)
        transaction_id = str(uuid.uuid4())

        return cls(
            headers=Headers(
                op=operation,
                ts_ms=current_ts,
                transaction_id=transaction_id
            ),
            data=data if isinstance(data, str) else json.dumps(data),
            systemOfRecord=SystemOfRecord(
                sourceSystem=source_system,
                sourceEntity=source_entity,
                sourcePublishedDate=datetime.now().isoformat(),
                sourceCorrelationReference=transaction_id,
                entityKey=str(data.get('member_id', uuid.uuid4()))
            )
        )

# Test data generation constants
FIRST_NAMES = [
    "Alice", "Bob", "Charlie", "Diana", "Eva", "Frank", "Grace", "Henry", "Ivy", "Jack",
    "Karen", "Leo", "Mona", "Ned", "Olivia", "Paul", "Quincy", "Rita", "Sam", "Tina"
]

LAST_NAMES = [
    "Smith", "Johnson", "Williams", "Brown", "Jones", "Miller", "Davis", "Garcia",
    "Martinez", "Robinson", "Clark", "Rodriguez", "Lewis", "Lee", "Walker", "Hall",
    "Allen", "Young", "King", "Wright"
]

CITIES = [
    "Springfield", "Riverside", "Greenwood", "Madison", "Franklin", "Clinton", "Fairview"
]

STREETS = [
    "123 Main St", "456 Maple Ave", "789 Oak Ln", "101 Pine Rd", "202 Cedar Dr"
]

STATES_AND_ZIPS = [
    ("IL", "62701"),
    ("CA", "90210"),
    ("NY", "10001"),
    ("TX", "73301"),
    ("FL", "33101"),
]

GENDERS = ["M", "F", "O"]

def generate_member_data(nb_records: int = 30) -> List[Dict]:
    """Generate a list of diverse synthetic member data records.
    
    Args:
        nb_records: Number of records to generate

    Returns:
        List of dictionaries containing member data
    """
    records = []
    used_names = set()
    
    for _ in range(nb_records):
        # Ensure some diversity in names
        first_name = random.choice(FIRST_NAMES)
        last_name = random.choice(LAST_NAMES)
        # Optionally, try to avoid repeat full names
        attempts = 0
        while (first_name, last_name) in used_names and attempts < 10:
            first_name = random.choice(FIRST_NAMES)
            last_name = random.choice(LAST_NAMES)
            attempts += 1
        used_names.add((first_name, last_name))

        state, zip_code = random.choice(STATES_AND_ZIPS)

        # Generate plausible date of birth between 1950 and 2010
        year = random.randint(1950, 2010)
        month = random.randint(1, 12)
        day = random.randint(1, 28)  # To avoid invalid days
        date_of_birth = f"{year:04d}-{month:02d}-{day:02d}"

        gender = random.choice(GENDERS)

        local_part = f"{first_name.lower()}.{last_name.lower()}".replace(" ", "")
        email = f"{local_part}@example.com"

        phone = "{}-{:03d}-{:04d}".format(
            random.randint(100, 999),
            random.randint(100, 999),
            random.randint(1000, 9999)
        )

        address = {
            "street": random.choice(STREETS),
            "city": random.choice(CITIES),
            "state": state,
            "zip": zip_code
        }

        records.append({
            "member_id": str(uuid.uuid4()),
            "first_name": first_name,
            "last_name": last_name,
            "date_of_birth": date_of_birth,
            "gender": gender,
            "email": email,
            "phone": phone,
            "address": address
        })
    return records