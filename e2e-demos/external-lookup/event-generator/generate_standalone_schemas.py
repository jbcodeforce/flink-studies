#!/usr/bin/env python3
"""
Standalone JSON Schema Generator for PaymentEvent

This script includes the PaymentEvent model definition inline to avoid import issues.
You can modify this script to include any other Pydantic models you want to generate schemas for.
"""

import json
from datetime import datetime
from decimal import Decimal
from enum import Enum
from typing import Optional
from pydantic import BaseModel, Field, ConfigDict


class PaymentStatus(str, Enum):
    """Payment processing status"""
    PENDING = "PENDING"
    PROCESSING = "PROCESSING"
    COMPLETED = "COMPLETED"
    FAILED = "FAILED"
    CANCELLED = "CANCELLED"


class PaymentMethod(str, Enum):
    """Payment method types"""
    ACH = "ACH"
    WIRE = "WIRE"
    CHECK = "CHECK"
    CARD = "CARD"
    ELECTRONIC = "ELECTRONIC"


class PaymentEvent(BaseModel):
    """
    Payment event model matching the design specification.
    
    This represents a payment transaction that references a claim_id
    for external lookup and enrichment.
    """
    model_config = ConfigDict(
        json_encoders={
            datetime: lambda v: v.isoformat(),
            Decimal: lambda v: float(v),
        }
    )
    
    # Core payment fields
    payment_id: str = Field(..., description="Unique payment identifier")
    claim_id: str = Field(..., description="Referenced claim ID for external lookup")
    payment_amount: Decimal = Field(..., description="Payment amount in USD", gt=0)
    payment_date: datetime = Field(default_factory=datetime.utcnow, description="Payment timestamp")
    processor_id: str = Field(..., description="Payment processor identifier")
    
    # Extended fields for realistic scenarios
    payment_method: PaymentMethod = Field(default=PaymentMethod.ELECTRONIC, description="Payment method")
    payment_status: PaymentStatus = Field(default=PaymentStatus.PENDING, description="Payment status")
    reference_number: Optional[str] = Field(None, description="External reference number")
    transaction_id: Optional[str] = Field(None, description="Bank transaction ID")
    notes: Optional[str] = Field(None, description="Payment notes")
    
    # Metadata
    created_by: str = Field(default="system", description="Created by user/system")


# Add your other Pydantic models here if needed
# class AnotherModel(BaseModel):
#     field1: str
#     field2: int


def generate_schema_for_model(model_class: BaseModel, output_file: str = None) -> dict:
    """Generate JSON schema for a Pydantic model"""
    schema = model_class.model_json_schema()
    
    print(f"JSON Schema for {model_class.__name__}:")
    print("=" * 50)
    print(json.dumps(schema, indent=2))
    
    if output_file:
        with open(output_file, 'w') as f:
            json.dump(schema, f, indent=2)
        print(f"\nSchema saved to: {output_file}")
    
    return schema


def main():
    """Generate schemas for all models defined in this file"""
    
    # Create schemas directory if it doesn't exist
    import os
    os.makedirs('schemas', exist_ok=True)
    
    # Generate schema for PaymentEvent
    generate_schema_for_model(PaymentEvent, 'schemas/payment_event_schema.json')
    
    # Add more models here as needed:
    # generate_schema_for_model(AnotherModel, 'schemas/another_model_schema.json')
    
    print("\nAll schemas generated successfully!")


if __name__ == "__main__":
    main()
