#!/usr/bin/env python3
"""
Simple test script to validate Pydantic models and JSON serialization
"""

import json
from decimal import Decimal
from datetime import datetime, timezone
from product_producer import Product, ProductEvent


def test_product_model():
    """Test Product model creation and validation"""
    print("🧪 Testing Product model...")
    
    product = Product(
        product_id=999,
        product_name="Test Product",
        description="A test product for validation",
        price=Decimal('99.99'),
        stock_quantity=10,
        discount=Decimal('5.00')
    )
    
    print(f"✅ Product created: {product.product_name} (ID: {product.product_id})")
    print(f"   Price: ${product.price}, Stock: {product.stock_quantity}")
    
    # Test JSON serialization
    product_json = product.model_dump_json()
    print(f"✅ JSON serialization works: {len(product_json)} characters")
    
    # Test deserialization
    product_dict = json.loads(product_json)
    reconstructed = Product(**product_dict)
    print(f"✅ JSON deserialization works: {reconstructed.product_name}")
    
    return product


def test_product_event_model():
    """Test ProductEvent model creation and validation"""
    print("\n🧪 Testing ProductEvent model...")
    
    product = Product(
        product_id=888,
        product_name="Event Test Product",
        description="A product for event testing",
        price=Decimal('199.99'),
        stock_quantity=25
    )
    
    event = ProductEvent(
        event_id="test_event_123",
        action="created",
        product=product,
        old_price=Decimal('179.99')
    )
    
    print(f"✅ ProductEvent created: {event.action} for {event.product.product_name}")
    print(f"   Event ID: {event.event_id}")
    
    # Test JSON serialization
    event_json = event.model_dump_json()
    print(f"✅ JSON serialization works: {len(event_json)} characters")
    
    # Test deserialization
    event_dict = json.loads(event_json)
    reconstructed = ProductEvent(**event_dict)
    print(f"✅ JSON deserialization works: {reconstructed.action} for {reconstructed.product.product_name}")
    
    return event


def test_validation():
    """Test Pydantic validation"""
    print("\n🧪 Testing validation...")
    
    try:
        # Test negative price validation
        Product(
            product_id=777,
            product_name="Invalid Product",
            price=Decimal('-10.00')  # This should fail
        )
        print("❌ Validation failed - negative price should be rejected")
    except ValueError as e:
        print("✅ Validation works - negative price rejected")
    
    try:
        # Test missing required field
        Product(
            product_id=666,
            # Missing product_name - this should fail
            price=Decimal('50.00')
        )
        print("❌ Validation failed - missing required field should be rejected")
    except ValueError as e:
        print("✅ Validation works - missing required field rejected")


def main():
    """Run all tests"""
    print("🚀 Running Pydantic model tests for dedup-demo...")
    
    try:
        product = test_product_model()
        event = test_product_event_model()
        test_validation()
        
        print("\n🎉 All tests passed!")
        print("\nSample ProductEvent JSON:")
        print("=" * 50)
        print(event.model_dump_json(indent=2))
        print("=" * 50)
        
    except Exception as e:
        print(f"\n❌ Test failed: {e}")
        raise


if __name__ == "__main__":
    main() 