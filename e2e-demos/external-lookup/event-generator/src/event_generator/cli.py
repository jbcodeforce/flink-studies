"""
Command-line interface for the payment event generator.

This module provides a user-friendly CLI for running the event generator
with various configurations and scenarios.
"""

import signal
import sys
import time
from pathlib import Path
from typing import Optional, List

import typer
from rich.console import Console
from rich.table import Table
from rich.progress import Progress, SpinnerColumn, TextColumn
from rich import print as rprint

from .models import PaymentEventConfig, ScenarioConfig
from .generator import PaymentEventGenerator

app = typer.Typer(
    name="payment-generator",
    help="Generate realistic payment events for external lookup demonstration",
    add_completion=False,
)

console = Console()
generator_instance: Optional[PaymentEventGenerator] = None


def signal_handler(signum, frame):
    """Handle interrupt signals gracefully"""
    if generator_instance:
        console.print("\n[yellow]Received interrupt signal, stopping generator...[/yellow]")
        generator_instance.stop()
    sys.exit(0)


signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)


@app.command()
def generate(
    # Kafka settings
    kafka_servers: str = typer.Option(
        "localhost:9092",
        "--kafka-servers", "-k",
        help="Kafka bootstrap servers"
    ),
    topic: str = typer.Option(
        "payment-events",
        "--topic", "-t", 
        help="Kafka topic name"
    ),
    
    # Generation settings
    rate: float = typer.Option(
        10.0,
        "--rate", "-r",
        min=0.1,
        help="Events per second"
    ),
    duration: int = typer.Option(
        300,
        "--duration", "-d",
        min=0,
        help="Run duration in seconds (0 = infinite)"
    ),
    
    # Scenario settings
    valid_rate: float = typer.Option(
        0.85,
        "--valid-rate", "-v",
        min=0.0, max=1.0,
        help="Rate of valid claim IDs (0-1)"
    ),
    
    # Mode settings
    burst: bool = typer.Option(
        False,
        "--burst", "-b",
        help="Enable burst mode"
    ),
    burst_size: int = typer.Option(
        100,
        "--burst-size",
        min=1,
        help="Events per burst"
    ),
    burst_interval: float = typer.Option(
        30.0,
        "--burst-interval",
        min=1.0,
        help="Seconds between bursts"
    ),
    
    # Output settings
    dry_run: bool = typer.Option(
        False,
        "--dry-run",
        help="Dry run mode (don't send to Kafka)"
    ),
    print_events: bool = typer.Option(
        False,
        "--print-events", "-p",
        help="Print events to stdout"
    ),
    log_level: str = typer.Option(
        "INFO",
        "--log-level", "-l",
        help="Log level (DEBUG, INFO, WARNING, ERROR)"
    ),
    yes: bool = typer.Option(
        False,
        "--yes", "-y",
        help="Skip interactive confirmation prompt"
    ),
    
    # Monitoring
    metrics_port: int = typer.Option(
        8090,
        "--metrics-port", "-m",
        help="Prometheus metrics port"
    ),
    
    # Configuration file
    config_file: Optional[Path] = typer.Option(
        None,
        "--config", "-c",
        help="Configuration file path"
    ),
):
    """
    Generate payment events and publish to Kafka.
    
    This command starts the payment event generator with the specified
    configuration. The generator will produce realistic payment events
    containing claim_id references for external lookup testing.
    """
    
    # Load configuration
    if config_file and config_file.exists():
        console.print(f"Loading configuration from {config_file}")
        # In a real implementation, we'd load from the config file
        # For now, use command line arguments
    
    # Create configuration
    config = PaymentEventConfig(
        kafka_bootstrap_servers=kafka_servers,
        kafka_topic=topic,
        events_per_second=rate,
        run_duration_seconds=duration,
        valid_claim_rate=valid_rate,
        burst_mode=burst,
        burst_size=burst_size,
        burst_interval_seconds=burst_interval,
        dry_run=dry_run,
        print_events=print_events,
        log_level=log_level.upper(),
        metrics_port=metrics_port,
    )
    
    # Display configuration
    _display_configuration(config)
    
    # Confirm start (skip if --yes flag is used)
    if not yes and not typer.confirm("Start event generation?"):
        console.print("[yellow]Cancelled[/yellow]")
        return
    
    # Create and start generator
    global generator_instance
    generator_instance = PaymentEventGenerator(config)
    
    console.print("[green]Starting payment event generator...[/green]")
    
    if duration > 0:
        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            console=console,
        ) as progress:
            task = progress.add_task(
                f"Generating events for {duration} seconds...",
                total=None
            )
            
            # Run generator in a thread to allow progress updates
            import threading
            
            def run_generator():
                generator_instance.start()
            
            gen_thread = threading.Thread(target=run_generator)
            gen_thread.daemon = True
            gen_thread.start()
            
            # Monitor progress
            start_time = time.time()
            while gen_thread.is_alive() and (time.time() - start_time) < duration:
                time.sleep(1)
                elapsed = time.time() - start_time
                remaining = max(0, duration - elapsed)
                progress.update(task, description=f"Generating events - {remaining:.0f}s remaining")
            
            # Stop generator
            generator_instance.stop()
            gen_thread.join(timeout=5)
    else:
        # Infinite duration
        console.print("[cyan]Running indefinitely... Press Ctrl+C to stop[/cyan]")
        generator_instance.start()


@app.command()
def scenarios():
    """
    List available test scenarios and their configurations.
    """
    config = PaymentEventConfig()
    
    table = Table(title="Available Test Scenarios")
    table.add_column("Name", style="cyan", no_wrap=True)
    table.add_column("Weight", justify="right", style="magenta")
    table.add_column("Valid Claim Rate", justify="right", style="green")
    table.add_column("Amount Range", style="yellow")
    table.add_column("Payment Methods", style="blue")
    
    for scenario in config.scenarios:
        methods = ", ".join([m.value for m in scenario.payment_methods[:3]])
        if len(scenario.payment_methods) > 3:
            methods += "..."
            
        table.add_row(
            scenario.name,
            f"{scenario.weight:.1%}",
            f"{scenario.valid_claim_rate:.1%}",
            f"${scenario.payment_amount_min} - ${scenario.payment_amount_max}",
            methods
        )
    
    console.print(table)


@app.command()
def test_kafka(
    kafka_servers: str = typer.Option(
        "localhost:9092",
        "--kafka-servers", "-k",
        help="Kafka bootstrap servers"
    ),
    topic: str = typer.Option(
        "payment-events",
        "--topic", "-t",
        help="Kafka topic name"
    ),
    count: int = typer.Option(
        5,
        "--count", "-n",
        min=1,
        help="Number of test events to send"
    )
):
    """
    Send test events to Kafka to verify connectivity.
    """
    console.print(f"[cyan]Testing Kafka connectivity to {kafka_servers}[/cyan]")
    
    config = PaymentEventConfig(
        kafka_bootstrap_servers=kafka_servers,
        kafka_topic=topic,
        events_per_second=1.0,
        run_duration_seconds=count,
        dry_run=False,
        print_events=True,
        log_level="INFO"
    )
    
    generator = PaymentEventGenerator(config)
    
    console.print(f"[green]Sending {count} test events to topic '{topic}'[/green]")
    
    try:
        # Generate test events
        for i in range(count):
            event = generator._generate_payment_event()
            success = generator._publish_event(event)
            
            if success:
                console.print(f"[green]✓[/green] Event {i+1}/{count}: {event.payment_id}")
            else:
                console.print(f"[red]✗[/red] Failed to send event {i+1}/{count}")
        
        # Flush producer
        if generator.producer:
            generator.producer.flush(timeout=10)
            
        console.print(f"[green]Successfully sent {count} test events[/green]")
        
    except Exception as e:
        console.print(f"[red]Error testing Kafka: {e}[/red]")
    finally:
        generator.stop()


@app.command()
def validate_claims(
    database_url: str = typer.Option(
        "http://localhost:8080",
        "--database-url", "-d",
        help="DuckDB API URL"
    )
):
    """
    Validate that claim IDs exist in the external database.
    """
    import requests
    
    config = PaymentEventConfig()
    
    console.print(f"[cyan]Validating claims against {database_url}[/cyan]")
    
    # Test valid claims
    console.print("\n[green]Testing valid claim IDs:[/green]")
    valid_count = 0
    for claim_id in config.valid_claim_ids[:5]:  # Test first 5
        try:
            response = requests.get(f"{database_url}/claims/{claim_id}", timeout=5)
            if response.status_code == 200:
                console.print(f"[green]✓[/green] {claim_id} - Found")
                valid_count += 1
            else:
                console.print(f"[red]✗[/red] {claim_id} - Not found (HTTP {response.status_code})")
        except Exception as e:
            console.print(f"[red]✗[/red] {claim_id} - Error: {e}")
    
    # Test invalid claims
    console.print("\n[yellow]Testing invalid claim IDs (should fail):[/yellow]")
    invalid_count = 0
    for claim_id in config.invalid_claim_ids[:3]:  # Test first 3
        try:
            response = requests.get(f"{database_url}/claims/{claim_id}", timeout=5)
            if response.status_code == 404:
                console.print(f"[green]✓[/green] {claim_id} - Correctly not found")
                invalid_count += 1
            else:
                console.print(f"[yellow]?[/yellow] {claim_id} - Unexpected response (HTTP {response.status_code})")
        except Exception as e:
            console.print(f"[red]✗[/red] {claim_id} - Error: {e}")
    
    console.print(f"\n[cyan]Validation Summary:[/cyan]")
    console.print(f"Valid claims working: {valid_count}/5")
    console.print(f"Invalid claims working: {invalid_count}/3")


def _display_configuration(config: PaymentEventConfig):
    """Display generator configuration in a nice table"""
    table = Table(title="Event Generator Configuration")
    table.add_column("Setting", style="cyan", no_wrap=True)
    table.add_column("Value", style="magenta")
    
    table.add_row("Kafka Servers", config.kafka_bootstrap_servers)
    table.add_row("Topic", config.kafka_topic)
    table.add_row("Events/Second", f"{config.events_per_second}")
    table.add_row("Duration", f"{config.run_duration_seconds}s" if config.run_duration_seconds > 0 else "Infinite")
    table.add_row("Valid Claim Rate", f"{config.valid_claim_rate:.1%}")
    table.add_row("Mode", "Burst" if config.burst_mode else "Continuous")
    table.add_row("Dry Run", "Yes" if config.dry_run else "No")
    table.add_row("Metrics Port", str(config.metrics_port))
    
    console.print(table)


if __name__ == "__main__":
    """Main entry point for the CLI"""
    app()


