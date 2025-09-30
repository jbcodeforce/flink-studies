"""
External Lookup Event Generator

This package generates realistic payment events for the external lookup demonstration.
It produces events to Kafka that contain claim_id references for testing the 
external database lookup functionality.
"""

__version__ = "0.1.0"
__author__ = "External Lookup Demo"
__email__ = "demo@example.com"

from .models import PaymentEvent, PaymentEventConfig
from .generator import PaymentEventGenerator

__all__ = ["PaymentEvent", "PaymentEventConfig", "PaymentEventGenerator"]

