"""
Payment event generator for Kafka.

This module contains the main logic for generating realistic payment events
and publishing them to Kafka for the external lookup demonstration.
"""

import json
import logging
import random
import time
import uuid
from datetime import datetime, timedelta
from decimal import Decimal
from typing import Optional, Dict, Any, List
from threading import Event, Thread

from confluent_kafka import Producer, KafkaException
from faker import Faker
from prometheus_client import Counter, Histogram, Gauge, start_http_server

from .models import (
    PaymentEvent, 
    PaymentEventConfig, 
    PaymentMethod, 
    PaymentStatus,
    ScenarioConfig
)

# Initialize Faker for realistic data generation
fake = Faker()

# Prometheus metrics
events_produced_total = Counter(
    'payment_events_produced_total', 
    'Total number of payment events produced',
    ['scenario', 'claim_valid']
)

events_failed_total = Counter(
    'payment_events_failed_total',
    'Total number of failed event productions',
    ['error_type']
)

kafka_delivery_duration = Histogram(
    'kafka_delivery_duration_seconds',
    'Time taken for Kafka message delivery'
)

events_per_second_gauge = Gauge(
    'payment_events_per_second',
    'Current rate of event generation'
)

logger = logging.getLogger(__name__)


class PaymentEventGenerator:
    """
    Generates realistic payment events and publishes them to Kafka.
    
    Features:
    - Configurable event rates and scenarios
    - Realistic data generation using Faker
    - Valid/invalid claim ID distribution
    - Prometheus metrics
    - Burst and continuous modes
    - Error handling and retries
    """
    
    def __init__(self, config: PaymentEventConfig):
        self.config = config
        self.producer: Optional[Producer] = None
        self.stop_event = Event()
        self.stats = {
            'events_produced': 0,
            'events_failed': 0,
            'valid_claims': 0,
            'invalid_claims': 0,
            'start_time': None,
        }
        
        # Configure logging
        logging.basicConfig(level=getattr(logging, config.log_level.upper()))
        
        # Start metrics server if enabled
        if config.enable_metrics:
            start_http_server(config.metrics_port)
            logger.info(f"Prometheus metrics server started on port {config.metrics_port}")
    
    def _create_producer(self) -> Producer:
        """Create and configure Kafka producer"""
        producer_config = {
            'bootstrap.servers': self.config.kafka_bootstrap_servers,
            'client.id': self.config.kafka_client_id,
            'acks': self.config.kafka_acks,
            'retries': self.config.kafka_retries,
            'batch.size': self.config.kafka_batch_size,
            'linger.ms': self.config.kafka_linger_ms,
            'compression.type': 'snappy',
            'max.in.flight.requests.per.connection': 5,
            'enable.idempotence': True,
        }
        
        return Producer(producer_config)
    
    def _delivery_callback(self, err, msg):
        """Callback for Kafka message delivery"""
        if err:
            logger.error(f"Message delivery failed: {err}")
            self.stats['events_failed'] += 1
            events_failed_total.labels(error_type='kafka_delivery').inc()
        else:
            logger.debug(f"Message delivered to {msg.topic()} [{msg.partition()}] @ {msg.offset()}")
    
    def _select_scenario(self) -> ScenarioConfig:
        """Select a test scenario based on configured weights"""
        total_weight = sum(s.weight for s in self.config.scenarios)
        if total_weight == 0:
            return self.config.scenarios[0]
        
        r = random.uniform(0, total_weight)
        cumulative_weight = 0
        
        for scenario in self.config.scenarios:
            cumulative_weight += scenario.weight
            if r <= cumulative_weight:
                return scenario
        
        return self.config.scenarios[-1]
    
    def _generate_claim_id(self, scenario: ScenarioConfig) -> tuple[str, bool]:
        """Generate a claim ID based on scenario configuration"""
        if random.random() < scenario.valid_claim_rate:
            claim_id = random.choice(self.config.valid_claim_ids)
            return claim_id, True
        else:
            claim_id = random.choice(self.config.invalid_claim_ids)
            return claim_id, False
    
    def _generate_payment_amount(self, scenario: ScenarioConfig) -> Decimal:
        """Generate realistic payment amount"""
        min_amount = float(scenario.payment_amount_min)
        max_amount = float(scenario.payment_amount_max)
        
        # Use log-normal distribution for more realistic amounts
        # Most payments are smaller, fewer are large
        mean_log = (min_amount + max_amount) / 2
        amount = random.lognormvariate(mean_log / 1000, 0.5) * 100
        
        # Clamp to scenario range
        amount = max(min_amount, min(max_amount, amount))
        
        # Round to 2 decimal places
        return Decimal(str(round(amount, 2)))
    
    def _generate_payment_event(self) -> PaymentEvent:
        """Generate a single realistic payment event"""
        # Select scenario for this event
        scenario = self._select_scenario()
        
        # Generate claim ID
        claim_id, is_valid_claim = self._generate_claim_id(scenario)
        
        # Generate realistic payment data
        payment_id = f"PAY-{uuid.uuid4().hex[:8].upper()}"
        payment_amount = self._generate_payment_amount(scenario)
        processor_id = random.choice(scenario.processor_ids or self.config.processor_ids)
        payment_method = random.choice(scenario.payment_methods)
        
        # Generate timestamp (recent past to now)
        payment_date = fake.date_time_between(
            start_date=datetime.now() - timedelta(hours=24),
            end_date=datetime.now()
        )
        
        # Generate optional fields
        reference_number = None
        transaction_id = None
        notes = None
        
        if random.random() < 0.7:  # 70% chance of reference number
            reference_number = f"REF-{uuid.uuid4().hex[:12].upper()}"
        
        if payment_method in [PaymentMethod.ACH, PaymentMethod.WIRE]:
            if random.random() < 0.8:  # 80% chance for bank transactions
                transaction_id = f"TXN-{uuid.uuid4().hex[:16].upper()}"
        
        if random.random() < 0.3:  # 30% chance of notes
            notes = fake.sentence(nb_words=8)
        
        # Create payment event
        event = PaymentEvent(
            payment_id=payment_id,
            claim_id=claim_id,
            payment_amount=payment_amount,
            payment_date=payment_date,
            processor_id=processor_id,
            payment_method=payment_method,
            payment_status=random.choice(list(PaymentStatus)),
            reference_number=reference_number,
            transaction_id=transaction_id,
            notes=notes,
            created_by="event-generator"
        )
        
        # Update stats
        if is_valid_claim:
            self.stats['valid_claims'] += 1
        else:
            self.stats['invalid_claims'] += 1
        
        # Update Prometheus metrics
        events_produced_total.labels(
            scenario=scenario.name,
            claim_valid=str(is_valid_claim).lower()
        ).inc()
        
        return event
    
    def _publish_event(self, event: PaymentEvent) -> bool:
        """Publish event to Kafka"""
        try:
            if self.config.dry_run:
                logger.info(f"DRY RUN: Would publish event {event.payment_id}")
                return True
            
            if self.config.print_events:
                print(f"Event: {json.dumps(event.to_kafka_dict(), indent=2)}")
            
            # Serialize event
            message_value = json.dumps(event.to_kafka_dict()).encode('utf-8')
            message_key = event.payment_id.encode('utf-8')
            
            # Publish to Kafka
            start_time = time.time()
            self.producer.produce(
                topic=self.config.kafka_topic,
                key=message_key,
                value=message_value,
                callback=self._delivery_callback
            )
            
            # Record delivery time
            kafka_delivery_duration.observe(time.time() - start_time)
            
            self.stats['events_produced'] += 1
            return True
            
        except KafkaException as e:
            logger.error(f"Failed to publish event {event.payment_id}: {e}")
            self.stats['events_failed'] += 1
            events_failed_total.labels(error_type='kafka_exception').inc()
            return False
        except Exception as e:
            logger.error(f"Unexpected error publishing event {event.payment_id}: {e}")
            self.stats['events_failed'] += 1
            events_failed_total.labels(error_type='unexpected').inc()
            return False
    
    def _calculate_sleep_time(self, target_rate: float, actual_duration: float) -> float:
        """Calculate sleep time to maintain target rate"""
        target_duration = 1.0 / target_rate
        sleep_time = target_duration - actual_duration
        return max(0, sleep_time)
    
    def _run_continuous_mode(self) -> None:
        """Run generator in continuous mode"""
        logger.info(f"Starting continuous mode at {self.config.events_per_second} events/sec")
        
        while not self.stop_event.is_set():
            start_time = time.time()
            
            # Generate and publish event
            event = self._generate_payment_event()
            self._publish_event(event)
            
            # Flush producer periodically
            if self.stats['events_produced'] % 100 == 0:
                self.producer.flush(timeout=1)
            
            # Calculate sleep time to maintain target rate
            generation_duration = time.time() - start_time
            sleep_time = self._calculate_sleep_time(
                self.config.events_per_second, 
                generation_duration
            )
            
            if sleep_time > 0:
                time.sleep(sleep_time)
            
            # Update rate metric
            if self.stats['start_time']:
                elapsed = time.time() - self.stats['start_time']
                current_rate = self.stats['events_produced'] / elapsed if elapsed > 0 else 0
                events_per_second_gauge.set(current_rate)
    
    def _run_burst_mode(self) -> None:
        """Run generator in burst mode"""
        logger.info(f"Starting burst mode: {self.config.burst_size} events every {self.config.burst_interval_seconds}s")
        
        while not self.stop_event.is_set():
            # Generate burst of events
            logger.info(f"Generating burst of {self.config.burst_size} events")
            for i in range(self.config.burst_size):
                if self.stop_event.is_set():
                    break
                
                event = self._generate_payment_event()
                self._publish_event(event)
            
            # Flush all events
            self.producer.flush(timeout=5)
            
            # Wait for next burst
            logger.info(f"Waiting {self.config.burst_interval_seconds}s until next burst")
            self.stop_event.wait(self.config.burst_interval_seconds)
    
    def start(self) -> None:
        """Start the event generator"""
        logger.info("Starting payment event generator")
        logger.info(f"Configuration: {self.config.model_dump()}")
        
        # Initialize producer
        self.producer = self._create_producer()
        self.stats['start_time'] = time.time()
        
        try:
            # Choose generation mode
            if self.config.burst_mode:
                self._run_burst_mode()
            else:
                self._run_continuous_mode()
                
        except KeyboardInterrupt:
            logger.info("Received interrupt signal")
        except Exception as e:
            logger.error(f"Generator error: {e}")
        finally:
            self.stop()
    
    def stop(self) -> None:
        """Stop the event generator"""
        logger.info("Stopping payment event generator")
        self.stop_event.set()
        
        if self.producer:
            # Flush remaining messages
            self.producer.flush(timeout=10)
            self.producer = None
        
        self._log_final_stats()
    
    def _log_final_stats(self) -> None:
        """Log final generation statistics"""
        if self.stats['start_time']:
            duration = time.time() - self.stats['start_time']
            rate = self.stats['events_produced'] / duration if duration > 0 else 0
            
            logger.info("=== Final Statistics ===")
            logger.info(f"Duration: {duration:.2f} seconds")
            logger.info(f"Events produced: {self.stats['events_produced']}")
            logger.info(f"Events failed: {self.stats['events_failed']}")
            logger.info(f"Average rate: {rate:.2f} events/sec")
            logger.info(f"Valid claims: {self.stats['valid_claims']}")
            logger.info(f"Invalid claims: {self.stats['invalid_claims']}")
            
            if self.stats['events_produced'] > 0:
                success_rate = (self.stats['events_produced'] - self.stats['events_failed']) / self.stats['events_produced'] * 100
                logger.info(f"Success rate: {success_rate:.1f}%")
                
                valid_rate = self.stats['valid_claims'] / self.stats['events_produced'] * 100
                logger.info(f"Valid claim rate: {valid_rate:.1f}%")
    
    def get_stats(self) -> Dict[str, Any]:
        """Get current generation statistics"""
        stats = self.stats.copy()
        if stats['start_time']:
            stats['duration'] = time.time() - stats['start_time']
            stats['rate'] = stats['events_produced'] / stats['duration'] if stats['duration'] > 0 else 0
        return stats

