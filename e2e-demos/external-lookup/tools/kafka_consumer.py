#!/usr/bin/env python3
"""
Simple Kafka Consumer for External Lookup Demo
Consumes messages from payment-events, enriched-payments, or failed-payments topics
"""

import json
import argparse
import sys
from datetime import datetime
from kafka import KafkaConsumer
from kafka.errors import NoBrokersAvailable, KafkaError
import signal

class SimpleKafkaConsumer:
    def __init__(self, bootstrap_servers, topic, group_id="simple-consumer", auto_offset_reset="latest"):
        self.bootstrap_servers = bootstrap_servers
        self.topic = topic
        self.group_id = group_id
        self.auto_offset_reset = auto_offset_reset
        self.consumer = None
        self.running = False
        
    def connect(self):
        """Connect to Kafka cluster"""
        try:
            print(f"🔗 Connecting to Kafka at {self.bootstrap_servers}")
            self.consumer = KafkaConsumer(
                self.topic,
                bootstrap_servers=self.bootstrap_servers,
                group_id=self.group_id,
                auto_offset_reset=self.auto_offset_reset,
                enable_auto_commit=True,
                value_deserializer=lambda x: x.decode('utf-8') if x else None,
                key_deserializer=lambda x: x.decode('utf-8') if x else None
            )
            print(f"✅ Connected to topic: {self.topic}")
            print(f"📊 Consumer group: {self.group_id}")
            print(f"🎯 Offset reset: {self.auto_offset_reset}")
            print("=" * 80)
            return True
        except NoBrokersAvailable:
            print(f"❌ No Kafka brokers available at {self.bootstrap_servers}")
            return False
        except Exception as e:
            print(f"❌ Failed to connect: {e}")
            return False
    
    def start_consuming(self, max_messages=None):
        """Start consuming messages"""
        if not self.consumer:
            if not self.connect():
                return
        
        self.running = True
        message_count = 0
        
        print(f"🎧 Listening for messages from topic '{self.topic}'...")
        print("Press Ctrl+C to stop")
        print("=" * 80)
        
        try:
            for message in self.consumer:
                if not self.running:
                    break
                    
                message_count += 1
                self.display_message(message, message_count)
                
                if max_messages and message_count >= max_messages:
                    print(f"\n🎯 Reached maximum messages ({max_messages}). Stopping...")
                    break
                    
        except KeyboardInterrupt:
            print("\n\n⏹️  Stopping consumer...")
        except KafkaError as e:
            print(f"\n❌ Kafka error: {e}")
        finally:
            self.stop()
    
    def display_message(self, message, count):
        """Display a message in a readable format"""
        timestamp = datetime.fromtimestamp(message.timestamp / 1000).strftime('%Y-%m-%d %H:%M:%S.%f')[:-3]
        
        print(f"\n📬 Message #{count}")
        print(f"🕒 Timestamp: {timestamp}")
        print(f"🏷️  Topic: {message.topic}")
        print(f"🔢 Partition: {message.partition}")
        print(f"📍 Offset: {message.offset}")
        
        if message.key:
            print(f"🔑 Key: {message.key}")
        
        # Try to parse as JSON for pretty printing
        try:
            if message.value:
                json_data = json.loads(message.value)
                print("📄 Value (JSON):")
                print(json.dumps(json_data, indent=2, ensure_ascii=False))
            else:
                print("📄 Value: <null>")
        except json.JSONDecodeError:
            print(f"📄 Value (Raw): {message.value}")
        
        print("-" * 80)
    
    def stop(self):
        """Stop the consumer"""
        self.running = False
        if self.consumer:
            self.consumer.close()
            print("✅ Consumer stopped")

def signal_handler(signum, frame):
    """Handle Ctrl+C gracefully"""
    print("\n🛑 Received interrupt signal")
    sys.exit(0)

def main():
    parser = argparse.ArgumentParser(
        description="Simple Kafka Consumer for External Lookup Demo",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Consume from payment-events (latest messages)
  python3 kafka_consumer.py -t payment-events
  
  # Consume from enriched-payments from beginning
  python3 kafka_consumer.py -t enriched-payments --from-beginning
  
  # Consume only 10 messages from failed-payments
  python3 kafka_consumer.py -t failed-payments --max-messages 10
  
  # Use custom Kafka broker
  python3 kafka_consumer.py -t payment-events -b kafka.example.com:9092
        """
    )
    
    parser.add_argument('-t', '--topic', required=True,
                        help='Kafka topic to consume from')
    parser.add_argument('-b', '--bootstrap-servers', default='localhost:9092',
                        help='Kafka bootstrap servers (default: localhost:9092)')
    parser.add_argument('-g', '--group-id', default='simple-consumer',
                        help='Consumer group ID (default: simple-consumer)')
    parser.add_argument('--from-beginning', action='store_true',
                        help='Start consuming from the beginning of the topic')
    parser.add_argument('--max-messages', type=int,
                        help='Maximum number of messages to consume')
    
    args = parser.parse_args()
    
    # Set up signal handler for graceful shutdown
    signal.signal(signal.SIGINT, signal_handler)
    
    # Determine offset reset strategy
    offset_reset = 'earliest' if args.from_beginning else 'latest'
    
    print("🚀 Simple Kafka Consumer")
    print("=" * 80)
    
    # Create and start consumer
    consumer = SimpleKafkaConsumer(
        bootstrap_servers=args.bootstrap_servers,
        topic=args.topic,
        group_id=args.group_id,
        auto_offset_reset=offset_reset
    )
    
    consumer.start_consuming(max_messages=args.max_messages)

if __name__ == "__main__":
    main()
