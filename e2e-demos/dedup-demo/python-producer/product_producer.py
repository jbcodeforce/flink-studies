import json
import random
import time
from datetime import datetime, timezone
from decimal import Decimal
from typing import Optional
from confluent_kafka import Producer
from pydantic import BaseModel, Field
import os

# Kafka configuration
KAFKA_BROKERS = os.getenv('KAFKA_BOOTSTRAP_SERVERS', 'localhost:30000')
KAFKA_CERT = os.getenv('KAFKA_CERT', '')
KAFKA_USER = os.getenv('KAFKA_USER', '')
KAFKA_PASSWORD = os.getenv('KAFKA_PASSWORD', '')
KAFKA_SASL_MECHANISM = os.getenv('KAFKA_SASL_MECHANISM', 'PLAIN')
KAFKA_SECURITY_PROTOCOL = os.getenv('KAFKA_SECURITY_PROTOCOL', 'PLAINTEXT')
PRODUCT_TOPIC_NAME = os.getenv("KAFKA_PRODUCT_TOPIC", "products")


class Product(BaseModel):
    """Product model matching the PostgreSQL schema"""
    product_id: int = Field(..., description="Primary key for the product")
    product_name: str = Field(..., max_length=255, description="Product name")
    description: Optional[str] = Field(None, description="Product description")
    price: Decimal = Field(..., ge=0, decimal_places=2, description="Product price")
    stock_quantity: int = Field(default=0, ge=0, description="Available stock quantity")
    discount: Decimal = Field(default=Decimal('0.00'), ge=0, decimal_places=2, description="Discount amount")
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    updated_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

    class Config:
        # Use string representation for decimals in JSON
        json_encoders = {
            Decimal: lambda v: str(v),
            datetime: lambda v: v.isoformat()
        }


class ProductEvent(BaseModel):
    """Event wrapper for product changes"""
    event_id: str = Field(..., description="Unique event identifier")
    action: str = Field(..., description="Type of action performed")
    timestamp: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    product: Product = Field(..., description="Product data")
    processed: bool = Field(default=False, description="Processing status")
    old_price: Optional[Decimal] = Field(None, description="Previous price for price_changed events")

    class Config:
        json_encoders = {
            Decimal: lambda v: str(v),
            datetime: lambda v: v.isoformat()
        }


# Sample product data matching the SQL schema
SAMPLE_PRODUCTS = [
    Product(
        product_id=1,
        product_name="Laptop Pro",
        description="High-performance laptop for professionals",
        price=Decimal('1299.99'),
        stock_quantity=25,
        discount=Decimal('0.00')
    ),
    Product(
        product_id=2,
        product_name="Wireless Headphones",
        description="Premium wireless headphones with noise cancellation",
        price=Decimal('199.99'),
        stock_quantity=50,
        discount=Decimal('15.00')
    ),
    Product(
        product_id=3,
        product_name="Coffee Maker",
        description="Programmable coffee maker with built-in grinder",
        price=Decimal('89.99'),
        stock_quantity=30,
        discount=Decimal('0.00')
    ),
    Product(
        product_id=4,
        product_name="Running Shoes",
        description="Lightweight running shoes with advanced cushioning",
        price=Decimal('129.99'),
        stock_quantity=75,
        discount=Decimal('20.00')
    ),
    Product(
        product_id=5,
        product_name="Smartphone",
        description="Latest smartphone with advanced camera system",
        price=Decimal('699.99'),
        stock_quantity=40,
        discount=Decimal('0.00')
    ),
    Product(
        product_id=6,
        product_name="Desk Chair",
        description="Ergonomic office chair with lumbar support",
        price=Decimal('249.99'),
        stock_quantity=20,
        discount=Decimal('25.00')
    ),
    Product(
        product_id=7,
        product_name="Water Bottle",
        description="Insulated stainless steel water bottle",
        price=Decimal('19.99'),
        stock_quantity=100,
        discount=Decimal('0.00')
    ),
    Product(
        product_id=8,
        product_name="Tablet",
        description="10-inch tablet with high-resolution display",
        price=Decimal('399.99'),
        stock_quantity=35,
        discount=Decimal('30.00')
    )
]

ACTIONS = ['created', 'updated', 'price_changed', 'stock_updated', 'deleted']


def generate_product_event() -> ProductEvent:
    """Generate a product event with potential for duplicates"""
    base_product = random.choice(SAMPLE_PRODUCTS)
    action = random.choice(ACTIONS)
    
    # Create a copy of the product for modification
    product_data = base_product.model_copy()
    product_data.updated_at = datetime.now(timezone.utc)
    
    # Generate unique event ID
    event_id = f"evt_{product_data.product_id}_{int(time.time())}_{random.randint(1000, 9999)}"
    
    event = ProductEvent(
        event_id=event_id,
        action=action,
        product=product_data,
        processed=False
    )
    
    # Apply action-specific modifications
    if action == 'price_changed':
        event.old_price = product_data.price
        new_price = round(float(product_data.price) * random.uniform(0.8, 1.2), 2)
        event.product.price = Decimal(str(new_price))
    elif action == 'stock_updated':
        event.product.stock_quantity = random.randint(0, 150)
    elif action == 'updated':
        event.product.description = f"Updated description for {product_data.product_name} - {datetime.now().strftime('%Y-%m-%d')}"
    elif action == 'created':
        event.product.created_at = datetime.now(timezone.utc)
        event.product.updated_at = datetime.now(timezone.utc)
    
    return event


def generate_duplicate_event(original_event: ProductEvent) -> ProductEvent:
    """Generate a duplicate event by copying the original but with a new event_id and timestamp"""
    # Create a deep copy of the original event
    duplicate_data = original_event.model_dump()
    
    # Update event metadata to simulate duplication
    duplicate_data['event_id'] = f"evt_{original_event.product.product_id}_{int(time.time())}_{random.randint(1000, 9999)}"
    duplicate_data['timestamp'] = datetime.now(timezone.utc).isoformat()
    
    return ProductEvent(**duplicate_data)


def create_kafka_producer():
    """Create and configure Kafka producer"""
    options = {
        'bootstrap.servers': KAFKA_BROKERS,
        'delivery.timeout.ms': 15000,
        'request.timeout.ms': 15000
    }
    
    print("kafka-user: " + KAFKA_USER)
    if KAFKA_USER != '':
        options['security.protocol'] = KAFKA_SECURITY_PROTOCOL
        options['sasl.mechanisms'] = KAFKA_SASL_MECHANISM
        options['sasl.username'] = KAFKA_USER
        options['sasl.password'] = KAFKA_PASSWORD

    if KAFKA_CERT != '':
        options['ssl.ca.location'] = KAFKA_CERT

    print("--- This is the configuration for the producer: ---")
    print('[KafkaProducer] - {}'.format(options))
    print("---------------------------------------------------")
    return Producer(options)


def delivery_report(err, msg):
    """Called once for each message produced to indicate delivery result."""
    if err is not None:
        print(f'Message delivery failed: {err}')
    else:
        print(f'Message delivered to {msg.topic()} [{msg.partition()}]')


def main():
    producer = create_kafka_producer()
    
    print(f"Starting to produce product events to topic: {PRODUCT_TOPIC_NAME}")
    print("Press Ctrl+C to stop...")
    
    recent_events = []  # Store recent events to create duplicates
    
    try:
        while True:
            # 70% chance of generating a new event, 30% chance of duplicating a recent event
            if random.random() < 0.7 or len(recent_events) == 0:
                event = generate_product_event()
                recent_events.append(event)
                # Keep only the last 5 events for potential duplication
                if len(recent_events) > 5:
                    recent_events.pop(0)
            else:
                # Generate a duplicate of a recent event
                original_event = random.choice(recent_events)
                event = generate_duplicate_event(original_event)
                print("🔄 Generating DUPLICATE event!")
            
            # Use product_id as the key for partitioning
            key = str(event.product.product_id)
            
            # Serialize to JSON using Pydantic's built-in serialization
            event_json = event.model_dump_json()
            
            # Produce the event
            producer.produce(
                PRODUCT_TOPIC_NAME,
                key=key,
                value=event_json,
                callback=delivery_report
            )
            
            print(f"📦 Sent event: {event.action} for product {event.product.product_name} (ID: {event.product.product_id})")
            if event.action == 'price_changed' and event.old_price:
                print(f"   💰 Price changed: ${event.old_price} → ${event.product.price}")
            elif event.action == 'stock_updated':
                print(f"   📦 Stock updated to: {event.product.stock_quantity}")
            
            # Flush to ensure delivery
            producer.poll(0)
            
            # Random delay between events
            time.sleep(random.uniform(1, 3))
            
    except KeyboardInterrupt:
        print("\n🛑 Stopping product event generation...")
    finally:
        print("⏳ Waiting for any outstanding messages to be delivered...")
        producer.flush()
        print("✅ Producer closed successfully")


if __name__ == "__main__":
    main() 