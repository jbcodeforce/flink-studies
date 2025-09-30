"""
Data models for payment events and configuration.
"""

from datetime import datetime
from decimal import Decimal
from enum import Enum
from typing import Optional, Dict, Any, List
from pydantic import BaseModel, Field, ConfigDict
from pydantic_settings import BaseSettings


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
    
    def to_kafka_dict(self) -> Dict[str, Any]:
        """Convert to dictionary suitable for Kafka publishing"""
        return {
            "payment_id": self.payment_id,
            "claim_id": self.claim_id,
            "payment_amount": float(self.payment_amount),
            "payment_date": self.payment_date.isoformat(),
            "processor_id": self.processor_id,
            "payment_method": self.payment_method.value,
            "payment_status": self.payment_status.value,
            "reference_number": self.reference_number,
            "transaction_id": self.transaction_id,
            "notes": self.notes,
            "created_by": self.created_by,
        }


class ScenarioConfig(BaseModel):
    """Configuration for different test scenarios"""
    name: str = Field(..., description="Scenario name")
    weight: float = Field(..., description="Probability weight (0-1)", ge=0, le=1)
    valid_claim_rate: float = Field(0.9, description="Rate of valid claim IDs", ge=0, le=1)
    payment_amount_min: Decimal = Field(Decimal("10.00"), description="Minimum payment amount")
    payment_amount_max: Decimal = Field(Decimal("10000.00"), description="Maximum payment amount")
    payment_methods: List[PaymentMethod] = Field(default_factory=lambda: list(PaymentMethod))
    processor_ids: List[str] = Field(default_factory=lambda: ["PROC-001", "PROC-002", "PROC-003"])


class PaymentEventConfig(BaseSettings):
    """Configuration for payment event generation"""
    
    # Kafka settings
    kafka_bootstrap_servers: str = Field("localhost:9092", description="Kafka bootstrap servers")
    kafka_topic: str = Field("payment-events", description="Kafka topic for payment events")
    kafka_client_id: str = Field("payment-event-generator", description="Kafka client ID")
    kafka_acks: str = Field("all", description="Kafka acknowledgment level")
    kafka_retries: int = Field(3, description="Kafka retry attempts")
    kafka_batch_size: int = Field(16384, description="Kafka batch size")
    kafka_linger_ms: int = Field(10, description="Kafka linger time in ms")
    
    # Generation settings
    events_per_second: float = Field(10.0, description="Target events per second", gt=0)
    run_duration_seconds: int = Field(300, description="How long to run generator (0 = infinite)", ge=0)
    burst_mode: bool = Field(False, description="Generate events in bursts")
    burst_size: int = Field(100, description="Events per burst")
    burst_interval_seconds: float = Field(30.0, description="Seconds between bursts")
    
    # Data generation settings
    valid_claim_ids: List[str] = Field(
        default_factory=lambda: [
            "CLM-001", "CLM-002", "CLM-003", "CLM-004", "CLM-005",
            "CLM-006", "CLM-007", "CLM-008", "CLM-009", "CLM-010", 
            "CLM-015", "CLM-016", "CLM-017", "CLM-018", "CLM-019",
            "CLAIM-TEST-001", "CLAIM-TEST-002", "CLAIM-TEST-003", 
            "CLAIM-TEST-004", "CLAIM-TEST-005"
        ],
        description="List of valid claim IDs that exist in database"
    )
    
    invalid_claim_ids: List[str] = Field(
        default_factory=lambda: [
            "CLAIM-INVALID-001", "CLAIM-INVALID-002", "CLAIM-MISSING-001",
            "CLAIM-NONEXISTENT-001", "CLAIM-FAKE-001", "CLM-999", "CLM-888"
        ],
        description="List of invalid claim IDs for error testing"
    )
    
    valid_claim_rate: float = Field(0.85, description="Rate of valid claim IDs (0-1)", ge=0, le=1)
    
    # Processor IDs
    processor_ids: List[str] = Field(
        default_factory=lambda: [
            "PROC-VISA-001", "PROC-MC-002", "PROC-ACH-003", 
            "PROC-WIRE-004", "PROC-CHECK-005", "PROC-AMEX-006"
        ],
        description="Available payment processor IDs"
    )
    
    # Amount ranges
    payment_amount_min: Decimal = Field(Decimal("5.00"), description="Minimum payment amount")
    payment_amount_max: Decimal = Field(Decimal("50000.00"), description="Maximum payment amount")
    
    # Test scenarios
    scenarios: List[ScenarioConfig] = Field(
        default_factory=lambda: [
            ScenarioConfig(
                name="normal_operations",
                weight=0.7,
                valid_claim_rate=0.95,
                payment_amount_min=Decimal("50.00"),
                payment_amount_max=Decimal("5000.00")
            ),
            ScenarioConfig(
                name="high_value_payments", 
                weight=0.15,
                valid_claim_rate=0.98,
                payment_amount_min=Decimal("5000.00"),
                payment_amount_max=Decimal("50000.00")
            ),
            ScenarioConfig(
                name="error_testing",
                weight=0.15,
                valid_claim_rate=0.5,
                payment_amount_min=Decimal("1.00"),
                payment_amount_max=Decimal("1000.00")
            ),
        ]
    )
    
    # Monitoring
    enable_metrics: bool = Field(True, description="Enable Prometheus metrics")
    metrics_port: int = Field(8090, description="Prometheus metrics port")
    log_level: str = Field("INFO", description="Log level")
    
    # Development/testing
    dry_run: bool = Field(False, description="Dry run mode (don't send to Kafka)")
    print_events: bool = Field(False, description="Print events to stdout")
    
    model_config = ConfigDict(
        env_prefix="PAYMENT_GEN_",
        env_file=".env",
        case_sensitive=False
    )

