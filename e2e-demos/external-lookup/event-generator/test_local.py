#!/usr/bin/env python3
"""
Quick local test script for the payment event generator.
This script tests the event generation without requiring Kafka.
"""

import json
from src.event_generator.models import PaymentEventConfig
from src.event_generator.generator import PaymentEventGenerator


def test_event_generation():
    """Test basic event generation functionality"""
    print("🧪 Testing Payment Event Generator")
    print("=" * 50)
    
    # Create test configuration
    config = PaymentEventConfig(
        dry_run=True,  # Don't send to Kafka
        print_events=True,  # Print to console
        events_per_second=2.0,
        run_duration_seconds=5,  # Run for 5 seconds
        log_level="INFO"
    )
    
    print("📋 Configuration:")
    print(f"  Events per second: {config.events_per_second}")
    print(f"  Valid claim rate: {config.valid_claim_rate}")
    print(f"  Duration: {config.run_duration_seconds}s")
    print(f"  Dry run: {config.dry_run}")
    print()
    
    # Create generator
    generator = PaymentEventGenerator(config)
    
    print("🎯 Generating sample events:")
    print("-" * 50)
    
    # Generate a few test events
    for i in range(5):
        event = generator._generate_payment_event()
        print(f"Event {i+1}:")
        print(json.dumps(event.to_kafka_dict(), indent=2))
        print()
    
    # Show final stats
    stats = generator.get_stats()
    print("📊 Generation Statistics:")
    print(f"  Valid claims: {stats['valid_claims']}")
    print(f"  Invalid claims: {stats['invalid_claims']}")
    
    if stats['valid_claims'] + stats['invalid_claims'] > 0:
        total = stats['valid_claims'] + stats['invalid_claims']
        valid_rate = stats['valid_claims'] / total * 100
        print(f"  Actual valid rate: {valid_rate:.1f}%")
    
    print("\n✅ Test completed successfully!")


if __name__ == "__main__":
    test_event_generation()
