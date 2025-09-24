#!/usr/bin/env python3
"""
Tendance - Stack Exchange Content Analyzer
Main CLI interface using Typer
"""

import sys
import json
import csv
from pathlib import Path
from typing import Optional, List
from datetime import datetime

import typer
from rich.console import Console
from rich.panel import Panel
from rich.text import Text
from rich.progress import Progress, SpinnerColumn, TextColumn, BarColumn, TaskProgressColumn
from rich.table import Table

from .api import (
    StackOverflowClient,
    QueryFilters,
    ClientConfig,
    QuestionSort,
    SortOrder,
    StackExchangeError,
    RateLimitError,
)
from .config import get_config, set_config_file, create_example_config
from .extractors import RAGContentExtractor
import os

# Create the main Typer app
app = typer.Typer(
    name="tendance",
    help="Stack Exchange Content Analyzer - Extract and analyze content for specific subjects",
    rich_markup_mode="rich"
)

# Console for rich output
console = Console()

__version__ = "0.1.0"


@app.command("version")
def version_command():
    """Display the current version of Tendance CLI."""
    version_text = Text(f"Tendance CLI version: {__version__}", style="bold green")
    description = Text("Stack Exchange Content Analyzer", style="dim")
    
    panel = Panel(
        Text.assemble(version_text, "\n", description),
        title="📊 Tendance",
        border_style="blue"
    )
    
    console.print(panel)


@app.command("analyze")
def analyze(
    subject: Optional[str] = typer.Option(
        None, 
        "--subject", "-s",
        help="Subject to analyze (e.g., apache-flink)"
    ),
    tags: Optional[str] = typer.Option(
        None,
        "--tags", "-t", 
        help="Comma-separated tags to search for"
    ),
    from_date: Optional[str] = typer.Option(
        None,
        "--from-date", "-f",
        help="Start date for content retrieval (YYYY-MM-DD)"
    ),
    to_date: Optional[str] = typer.Option(
        None,
        "--to-date",
        help="End date for content retrieval (YYYY-MM-DD)"
    ),
    config: Optional[Path] = typer.Option(
        None,
        "--config", "-c",
        help="Path to configuration file"
    ),
    output_dir: Path = typer.Option(
        Path("./output"),
        "--output-dir", "-o",
        help="Output directory"
    ),
    formats: str = typer.Option(
        "json",
        "--formats",
        help="Output formats (json,csv,markdown)"
    ),
    min_score: int = typer.Option(
        0,
        "--min-score",
        help="Minimum score threshold"
    ),
    resume: Optional[Path] = typer.Option(
        None,
        "--resume",
        help="Resume from previous state file"
    )
):
    """Analyze Stack Exchange content for a specific subject."""
    
    # Load configuration
    if config:
        set_config_file(str(config))
    
    app_config = get_config()
    
    if not subject and not config:
        console.print("[red]❌ Error:[/red] Either --subject or --config must be provided")
        console.print("[yellow]💡 Try:[/yellow] tendance analyze --subject apache-flink --from-date 2024-01-01")
        console.print("[yellow]🔧 Or:[/yellow]  tendance analyze --config config/apache_flink.yaml")
        console.print("[yellow]🌐 Or:[/yellow]  tendance ui  (for web dashboard)")
        raise typer.Exit(1)
    
    # Parse dates
    parsed_from_date = None
    parsed_to_date = None
    
    if from_date:
        try:
            parsed_from_date = datetime.strptime(from_date, "%Y-%m-%d")
        except ValueError:
            console.print(f"[red]❌ Error:[/red] Invalid from_date format: {from_date}. Use YYYY-MM-DD")
            raise typer.Exit(1)
    
    if to_date:
        try:
            parsed_to_date = datetime.strptime(to_date, "%Y-%m-%d")
        except ValueError:
            console.print(f"[red]❌ Error:[/red] Invalid to_date format: {to_date}. Use YYYY-MM-DD")
            raise typer.Exit(1)
    
    # Parse tags
    tag_list = None
    if tags:
        tag_list = [tag.strip() for tag in tags.split(',') if tag.strip()]
    elif subject:
        tag_list = app_config.get_tags_for_subject(subject)
    
    # Use config defaults if not specified
    if min_score == 0 and subject:
        subject_config = app_config.get_subject_config(subject)
        if subject_config:
            min_score = subject_config.min_score
    
    # Parse output formats - use config default if not specified
    if formats == "json":  # Default value from CLI
        format_list = app_config.output.default_formats
    else:
        format_list = [f.strip().lower() for f in formats.split(',') if f.strip()]
    
    valid_formats = {'json', 'csv', 'markdown', 'rag-jsonl', 'rag-text', 'rag-md'}
    invalid_formats = set(format_list) - valid_formats
    if invalid_formats:
        console.print(f"[red]❌ Error:[/red] Invalid output formats: {', '.join(invalid_formats)}")
        console.print(f"[yellow]Valid formats:[/yellow] {', '.join(valid_formats)}")
        console.print(f"[cyan]RAG formats:[/cyan] rag-jsonl (JSON Lines), rag-text (structured text), rag-md (markdown)")
        raise typer.Exit(1)
    
    # Use config default output directory if using default
    if str(output_dir) == "output":  # Default CLI value
        output_dir = Path(app_config.output.default_directory)
    
    # Ensure output directory exists
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # Display analysis info
    console.print("\n[blue]🔍 Tendance Stack Exchange Analyzer[/blue]")
    console.print(f"[green]📋 Subject:[/green] {subject or 'From config file'}")
    console.print(f"[green]🏷️  Tags:[/green] {', '.join(tag_list) if tag_list else 'None'}")
    console.print(f"[green]📅 Date range:[/green] {from_date or 'Any'} to {to_date or 'current'}")
    console.print(f"[green]📂 Output:[/green] {output_dir} ({', '.join(format_list)})")
    console.print(f"[green]🎯 Min score:[/green] {min_score}")
    console.print()
    
    # Initialize Stack Overflow client with configuration
    try:
        client_config = ClientConfig(
            api_key=app_config.api.api_key,
            site=app_config.api.site,
            default_page_size=app_config.api.default_page_size,
            max_retries=app_config.api.max_retries,
            timeout_seconds=app_config.api.timeout_seconds,
            respect_backoff=app_config.api.respect_backoff,
            user_agent=app_config.api.user_agent
        )
        client = StackOverflowClient(client_config)
    except Exception as e:
        console.print(f"[red]❌ Error initializing client:[/red] {e}")
        raise typer.Exit(1)
    
    # Create query filters
    filters = QueryFilters(
        tags=tag_list,
        from_date=parsed_from_date,
        to_date=parsed_to_date,
        min_score=min_score,
        sort=QuestionSort.CREATION,
        order=SortOrder.DESC,
        page_size=app_config.api.default_page_size
    )
    
    # Collect questions with progress indication
    all_questions = []
    
    try:
        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            BarColumn(),
            TaskProgressColumn(),
            console=console
        ) as progress:
            
            # Start initial task
            task = progress.add_task("Fetching questions...", total=None)
            
            page_count = 0
            max_pages = app_config.api.max_pages_cli
            
            for response in client.get_questions_by_apache_flink(
                from_date=parsed_from_date,
                to_date=parsed_to_date,
                min_score=min_score
            ):
                page_count += 1
                questions_in_page = len(response.questions)
                all_questions.extend(response.questions)
                
                progress.update(
                    task, 
                    description=f"Fetching questions... (page {page_count}, {len(all_questions)} total)",
                    advance=1
                )
                
                if page_count >= max_pages or not response.has_more:
                    break
            
            progress.update(task, description=f"✅ Collected {len(all_questions)} questions")
    
    except RateLimitError as e:
        console.print(f"[red]❌ Rate limit exceeded:[/red] {e}")
        console.print("[yellow]💡 Tip:[/yellow] Get an API key at https://stackapps.com/apps/oauth/register")
        raise typer.Exit(1)
    except StackExchangeError as e:
        console.print(f"[red]❌ API Error:[/red] {e}")
        raise typer.Exit(1)
    except Exception as e:
        console.print(f"[red]❌ Unexpected error:[/red] {e}")
        raise typer.Exit(1)
    
    if not all_questions:
        console.print("[yellow]⚠️  No questions found matching the criteria[/yellow]")
        return
    
    # Check if RAG extraction is requested
    rag_formats = [f for f in format_list if f.startswith('rag-')]
    regular_formats = [f for f in format_list if not f.startswith('rag-')]
    
    # Extract RAG knowledge if RAG formats are requested
    rag_entries = []
    if rag_formats:
        console.print("\n[blue]🧠 Extracting RAG Knowledge...[/blue]")
        
        try:
            with Progress(
                SpinnerColumn(),
                TextColumn("[progress.description]{task.description}"),
                console=console
            ) as progress:
                task = progress.add_task("Extracting knowledge from answers...", total=None)
                
                rag_entries = client.extract_rag_knowledge(
                    all_questions,
                    include_code=True,
                    min_answer_score=max(0, min_score - 1),  # Slightly lower threshold for answers
                    max_answers_per_question=3
                )
                
                progress.update(task, description=f"✅ Extracted {len(rag_entries)} knowledge entries")
        
        except Exception as e:
            console.print(f"[red]❌ Error extracting RAG knowledge:[/red] {e}")
            # Continue with regular processing
    
    # Generate statistics
    stats = client.get_question_statistics(all_questions)
    
    # Display summary
    console.print("\n[blue]📊 Analysis Summary[/blue]")
    
    table = Table(title="Question Statistics")
    table.add_column("Metric", style="cyan", no_wrap=True)
    table.add_column("Value", style="green")
    
    table.add_row("Total Questions", str(stats['total_questions']))
    table.add_row("Answered Questions", f"{stats['answered_questions']} ({stats['answer_rate']:.1%})")
    table.add_row("Accepted Answers", f"{stats['accepted_answers']} ({stats['acceptance_rate']:.1%})")
    table.add_row("Average Score", f"{stats['score_statistics']['average']:.1f}")
    table.add_row("Total Views", f"{stats['view_statistics']['total']:,}")
    table.add_row("Average Views", f"{stats['view_statistics']['average']:.0f}")
    
    if stats.get('date_range'):
        table.add_row("Date Span", f"{stats['date_range']['span_days']} days")
    
    console.print(table)
    
    # Show top tags
    if stats.get('top_tags'):
        console.print("\n[blue]🏷️  Top Tags[/blue]")
        for i, (tag, count) in enumerate(stats['top_tags'][:5], 1):
            console.print(f"  {i}. [green]{tag}[/green]: {count} questions")
    
    # Show rate limit info
    rate_limit = client.get_rate_limit_info()
    if rate_limit:
        console.print(f"\n[yellow]📊 API Usage:[/yellow] {rate_limit.quota_remaining}/{rate_limit.quota_max} requests remaining")
    
    # Save in requested formats
    timestamp = datetime.now().strftime(app_config.output.timestamp_format)
    base_filename = f"{subject or 'questions'}_{timestamp}"
    
    console.print(f"\n[blue]💾 Saving results to {output_dir}[/blue]")
    
    # Save regular formats
    for format_type in regular_formats:
        try:
            if format_type == 'json':
                _save_json(all_questions, stats, output_dir / f"{base_filename}.json")
                console.print(f"  ✅ Saved JSON: [cyan]{base_filename}.json[/cyan]")
            
            elif format_type == 'csv':
                _save_csv(all_questions, output_dir / f"{base_filename}.csv")
                console.print(f"  ✅ Saved CSV: [cyan]{base_filename}.csv[/cyan]")
            
            elif format_type == 'markdown':
                _save_markdown(all_questions, stats, subject, output_dir / f"{base_filename}.md")
                console.print(f"  ✅ Saved Markdown: [cyan]{base_filename}.md[/cyan]")
        
        except Exception as e:
            console.print(f"  [red]❌ Error saving {format_type}:[/red] {e}")
    
    # Save RAG formats
    if rag_entries:
        extractor = RAGContentExtractor()
        rag_stats = extractor.get_statistics(rag_entries)
        
        for format_type in rag_formats:
            try:
                if format_type == 'rag-jsonl':
                    extractor.save_as_jsonl(rag_entries, output_dir / f"{base_filename}_knowledge.jsonl")
                    console.print(f"  ✅ Saved RAG JSONL: [cyan]{base_filename}_knowledge.jsonl[/cyan]")
                
                elif format_type == 'rag-text':
                    extractor.save_as_text(rag_entries, output_dir / f"{base_filename}_knowledge.txt")
                    console.print(f"  ✅ Saved RAG Text: [cyan]{base_filename}_knowledge.txt[/cyan]")
                
                elif format_type == 'rag-md':
                    extractor.save_as_markdown(rag_entries, output_dir / f"{base_filename}_knowledge.md")
                    console.print(f"  ✅ Saved RAG Markdown: [cyan]{base_filename}_knowledge.md[/cyan]")
            
            except Exception as e:
                console.print(f"  [red]❌ Error saving {format_type}:[/red] {e}")
        
        # Display RAG statistics
        if rag_stats:
            console.print(f"\n[blue]🧠 RAG Knowledge Statistics[/blue]")
            console.print(f"  📚 Total entries: {rag_stats['total_entries']}")
            console.print(f"  ✅ Accepted answers: {rag_stats['accepted_answers']} ({rag_stats['acceptance_rate']:.1f}%)")
            console.print(f"  ⭐ Average score: {rag_stats['average_score']:.1f}")
            if rag_stats.get('top_tags'):
                top_3_tags = rag_stats['top_tags'][:3]
                console.print(f"  🏷️  Top tags: {', '.join([f'{tag} ({count})' for tag, count in top_3_tags])}")
    
    total_results = len(all_questions)
    if rag_entries:
        total_results = f"{len(all_questions)} questions, {len(rag_entries)} RAG entries"
    
    console.print(f"\n[green]🎉 Analysis complete![/green] Found {total_results}.")
    console.print(f"[yellow]💡 Tip:[/yellow] Use [cyan]tendance ui[/cyan] for interactive visualization")
    if rag_entries:
        console.print(f"[yellow]🧠 RAG Tip:[/yellow] Use the generated knowledge files with your favorite RAG system!")


def _save_json(questions: List, stats: dict, file_path: Path):
    """Save questions and stats to JSON file"""
    data = {
        'metadata': {
            'generated_at': datetime.now().isoformat(),
            'total_questions': len(questions),
            'tool_version': __version__
        },
        'statistics': stats,
        'questions': [
            {
                'question_id': q.question_id,
                'title': q.title,
                'link': q.link,
                'tags': q.tags,
                'score': q.score,
                'view_count': q.view_count,
                'answer_count': q.answer_count,
                'is_answered': q.is_answered,
                'creation_date': q.creation_date.isoformat() if q.creation_date else None,
                'last_activity_date': q.last_activity_date.isoformat() if q.last_activity_date else None,
                'accepted_answer_id': q.accepted_answer_id
            }
            for q in questions
        ]
    }
    
    with open(file_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)


def _save_csv(questions: List, file_path: Path):
    """Save questions to CSV file"""
    with open(file_path, 'w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        
        # Header
        writer.writerow([
            'question_id', 'title', 'link', 'tags', 'score', 'view_count', 
            'answer_count', 'is_answered', 'creation_date', 'last_activity_date'
        ])
        
        # Data
        for q in questions:
            writer.writerow([
                q.question_id,
                q.title,
                q.link,
                '; '.join(q.tags) if q.tags else '',
                q.score,
                q.view_count,
                q.answer_count,
                q.is_answered,
                q.creation_date.isoformat() if q.creation_date else '',
                q.last_activity_date.isoformat() if q.last_activity_date else ''
            ])


def _save_markdown(questions: List, stats: dict, subject: str, file_path: Path):
    """Save questions and stats to Markdown file"""
    
    content = f"""# Tendance Analysis Report

**Subject**: {subject or 'Stack Exchange Questions'}  
**Generated**: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}  
**Total Questions**: {len(questions)}

## 📊 Statistics Summary

| Metric | Value |
|--------|-------|
| Total Questions | {stats['total_questions']} |
| Answered Questions | {stats['answered_questions']} ({stats['answer_rate']:.1%}) |
| Accepted Answers | {stats['accepted_answers']} ({stats['acceptance_rate']:.1%}) |
| Average Score | {stats['score_statistics']['average']:.1f} |
| Total Views | {stats['view_statistics']['total']:,} |
| Average Views | {stats['view_statistics']['average']:.0f} |
"""

    if stats.get('date_range'):
        content += f"| Date Span | {stats['date_range']['span_days']} days |\n"

    # Top Tags
    if stats.get('top_tags'):
        content += f"\n## 🏷️ Top Tags\n\n"
        for i, (tag, count) in enumerate(stats['top_tags'][:10], 1):
            content += f"{i}. **{tag}**: {count} questions\n"

    # Questions list
    content += f"\n## 📋 Questions\n\n"
    
    for i, q in enumerate(questions, 1):
        answered = "✅" if q.is_answered else "❓"
        content += f"### {i}. {q.title}\n\n"
        content += f"- **Link**: [{q.link}]({q.link})\n"
        content += f"- **Score**: {q.score} | **Views**: {q.view_count:,} | **Answers**: {q.answer_count} {answered}\n"
        content += f"- **Tags**: {', '.join(f'`{tag}`' for tag in q.tags) if q.tags else 'None'}\n"
        content += f"- **Created**: {q.creation_date.strftime('%Y-%m-%d') if q.creation_date else 'Unknown'}\n\n"
    
    content += f"\n---\n*Generated by Tendance v{__version__}*"
    
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)


@app.command("ui")
def ui(
    subject: Optional[str] = typer.Option(
        None, 
        "--subject", "-s",
        help="Subject to analyze (e.g., apache-flink)"
    ),
    config: Optional[Path] = typer.Option(
        None,
        "--config", "-c",
        help="Path to configuration file"
    ),
    port: int = typer.Option(
        8501,
        "--port", "-p",
        help="Port for web dashboard (default: 8501)"
    )
):
    """Launch the interactive web dashboard."""
    
    console.print("[blue]🚀 Launching Tendance Web Dashboard...[/blue]")
    
    if subject:
        console.print(f"[green]📋 Subject:[/green] {subject}")
    if config:
        console.print(f"[green]🔧 Config:[/green] {config}")
    
    # Load configuration for UI
    if config:
        set_config_file(str(config))
    
    app_config = get_config()
    
    # Use config defaults if using CLI defaults
    if port == 8501:  # Default CLI value
        port = app_config.ui.default_port
    
    host = app_config.ui.host
    
    try:
        # Import and run Taipy app
        from .ui import TendanceApp
        
        console.print(f"[green]🚀 Starting Tendance Web Interface...[/green]")
        console.print(f"[blue]📊 Dashboard URL:[/blue] http://{host}:{port}")
        
        if subject:
            console.print(f"[green]📋 Subject filter:[/green] {subject}")
        if config:
            console.print(f"[green]🔧 Config file:[/green] {config}")
        
        # Determine output directory for dataset loading
        output_dir = "./output"
        if config:
            # If config is provided, look for datasets in the configured output directory
            output_dir = app_config.output.default_directory
        
        console.print(f"[yellow]📁 Looking for datasets in:[/yellow] {output_dir}")
        console.print("[cyan]💡 Tip:[/cyan] Run 'tendance analyze' first to generate datasets")
        console.print()
        
        # Create and run Taipy app
        taipy_app = TendanceApp(output_directory=output_dir, host=host, port=port)
        taipy_app.run()
        
    except ImportError:
        console.print("[red]❌ Web UI dependencies not installed![/red]")
        console.print("[cyan]🔧 Run `uv sync --extra web` to install web dependencies[/cyan]")
        raise typer.Exit(1)
    except Exception as e:
        console.print(f"[red]❌ Error starting web UI:[/red] {e}")
        raise typer.Exit(1)


@app.command("config")
def config_command(
    create: bool = typer.Option(
        False,
        "--create",
        help="Create an example configuration file"
    ),
    file: str = typer.Option(
        "tendance-config.yaml",
        "--file", "-f",
        help="Configuration file path"
    ),
    show: bool = typer.Option(
        False,
        "--show",
        help="Show current configuration"
    ),
    validate: bool = typer.Option(
        False,
        "--validate",
        help="Validate configuration file"
    )
):
    """Manage Tendance configuration files."""
    
    if create:
        try:
            create_example_config(file)
            console.print(f"[green]✅ Created example configuration:[/green] {file}")
            console.print("[yellow]💡 Edit the file and set CONFIG_FILE environment variable:[/yellow]")
            console.print(f"[cyan]export CONFIG_FILE={file}[/cyan]")
        except Exception as e:
            console.print(f"[red]❌ Error creating config file:[/red] {e}")
            raise typer.Exit(1)
    
    elif show:
        try:
            app_config = get_config()
            console.print("[blue]📋 Current Configuration[/blue]")
            
            # Display key settings
            table = Table(title="Configuration Summary")
            table.add_column("Setting", style="cyan")
            table.add_column("Value", style="green")
            
            table.add_row("Version", app_config.version)
            table.add_row("Debug Mode", str(app_config.debug))
            table.add_row("API Site", app_config.api.site)
            table.add_row("API Key Set", "Yes" if app_config.api.api_key else "No")
            table.add_row("Default Page Size", str(app_config.api.default_page_size))
            table.add_row("Max CLI Pages", str(app_config.api.max_pages_cli))
            table.add_row("Output Directory", app_config.output.default_directory)
            table.add_row("Default Formats", ", ".join(app_config.output.default_formats))
            table.add_row("UI Port", str(app_config.ui.default_port))
            table.add_row("Logging Level", app_config.logging.level)
            
            console.print(table)
            
            # Show configured subjects
            if app_config.subjects:
                console.print("\n[blue]🏷️  Configured Subjects[/blue]")
                for subject_id, subject_config in app_config.subjects.items():
                    console.print(f"  [green]{subject_id}[/green]: {subject_config.name}")
                    console.print(f"    Tags: {', '.join(subject_config.tags)}")
                    console.print(f"    Min Score: {subject_config.min_score}")
                    if subject_config.description:
                        console.print(f"    Description: {subject_config.description}")
                    console.print()
        
        except Exception as e:
            console.print(f"[red]❌ Error showing configuration:[/red] {e}")
            raise typer.Exit(1)
    
    elif validate:
        try:
            if os.path.exists(file):
                set_config_file(file)
                app_config = get_config()
                console.print(f"[green]✅ Configuration file is valid:[/green] {file}")
                console.print(f"[blue]📋 Loaded {len(app_config.subjects)} subjects[/blue]")
            else:
                console.print(f"[red]❌ Configuration file not found:[/red] {file}")
                raise typer.Exit(1)
                
        except Exception as e:
            console.print(f"[red]❌ Configuration validation failed:[/red] {e}")
            raise typer.Exit(1)
    
    else:
        # Show help if no action specified
        console.print("[yellow]💡 Available config commands:[/yellow]")
        console.print("  [cyan]tendance config --create[/cyan] - Create example config file")
        console.print("  [cyan]tendance config --show[/cyan] - Show current configuration")
        console.print("  [cyan]tendance config --validate -f config.yaml[/cyan] - Validate config file")


if __name__ == "__main__":
    app()