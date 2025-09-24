# Tendance - Stack Exchange Content Analyzer

A Python tool to extract and analyze Stack Exchange content for specific subjects with date-based filtering. Initially focused on Apache Flink, but extensible to any Stack Exchange tagged subject.

## 📋 Project Overview

**Tendance** (French for "trend") analyzes Stack Exchange content trends over time for specific technical subjects. The tool retrieves questions, answers, and metadata from Stack Exchange sites (primarily Stack Overflow) to help understand community interest, problem patterns, and knowledge evolution.

### Initial Use Case

- **Subject**: Apache Flink
- **Goal**: Track questions, answers, and trends from a specific date forward
- **Output**: Structured data for analysis and reporting

---

## 🎯 Requirements

### Functional Requirements

#### Core Features
- [x] **Subject-based Content Retrieval**
  - Fetch questions and answers by Stack Exchange tags (e.g., `apache-flink`)
  - Support multiple related tags (e.g., `apache-flink`, `flink-sql`, `flink-streaming`)
  - Filter content by date ranges (from specific date to present)

- [ ] **Data Extraction & Processing**
  - Extract question metadata (title, tags, score, view count, creation date)
  - Extract answer metadata (score, acceptance status, creation date)
  - Parse and clean HTML content from questions/answers
  - Identify and extract code snippets from content

- [ ] **Output & Export**
  - Export data in multiple formats (JSON, CSV, Markdown)
  - Generate summary reports with statistics
  - Create time-series data for trend analysis
  - have a --ui for start a webapp to present the statistics

- [ ] **Configuration & Flexibility**
  - Command-line interface with configurable parameters
  - Configuration file support for complex queries
  - Extensible architecture for new subjects/tags

#### Advanced Features (Future)
- [ ] Content sentiment analysis
- [ ] Automated categorization of problems/solutions
- [ ] Integration with Flink documentation for gap analysis
- [ ] Trend visualization and reporting
- [ ] Build a Retrieved Augmented Generation, RAG, Vector store, so the chat is integrated in LLM
- [ ] Duplicate question detection and clustering

### Technical Requirements

#### Runtime Environment
- **Python Version**: 3.11+ (as specified in pyproject.toml)
- **Operating System**: Cross-platform (macOS, Linux, Windows)
- **Memory**: Minimum 512MB RAM for basic operations
- **Storage**: Variable based on data volume (estimate 1MB per 1000 questions)

#### Dependencies
- [ ] **Core Libraries**
  - `requests` - HTTP API interactions
  - `stackapi` - Stack Exchange API wrapper
  - `typer` - Command-line interface
  - `pydantic` - Data validation and serialization
  - `python-dateutil` - Date parsing and manipulation

- [ ] **Data Processing**
  - `beautifulsoup4` - HTML content parsing
  - `pandas` - Data manipulation and analysis
  - `python-dotenv` - Environment configuration

- [ ] **Output & Export**
  - `jinja2` - Template rendering for reports
  - `rich` - Enhanced terminal output and progress bars

- [ ] **Web UI (Optional)**
  - `plotly` - Interactive data visualizations
  - `fastapi` - REST API backend for advanced features
  - `uvicorn` - ASGI server for FastAPI

#### API Requirements
- [ ] **Stack Exchange API**
  - API Key registration for higher rate limits (10,000 requests/day vs 300)
  - Rate limiting compliance (30 requests per second max)
  - Proper error handling for API failures
  - Caching mechanism to avoid redundant requests

#### Performance Requirements
- [ ] **Efficiency**
  - Handle large datasets (10,000+ questions) efficiently
  - Implement pagination for large result sets
  - Progress indication for long-running operations
  - Graceful handling of network interruptions

- [ ] **Reliability**
  - Robust error handling and recovery
  - Input validation and sanitization
  - Logging for debugging and monitoring
  - Resume capability for interrupted operations

---

## 🏗️ Architecture Design

### Component Structure
```
tendance/
├── src/tendance/
│   ├── __init__.py
│   ├── cli.py              # Command-line interface
│   ├── config.py           # Configuration management
│   ├── api/
│   │   ├── __init__.py
│   │   ├── so_client.py       # Stack Exchange API client
│   │   └── models.py       # Data models (Pydantic)
│   ├── processors/
│   │   ├── __init__.py
│   │   ├── content.py      # Content cleaning and parsing
│   │   └── analyzer.py     # Data analysis and metricsco
│   ├── exporters/
│   │   ├── __init__.py
│   │   ├── json.py         # JSON export
│   │   ├── csv.py          # CSV export
│   │   └── markdown.py     # Markdown report generation
│   ├── web/
│   │   ├── __init__.py
│   │   ├── dashboard.py    # Taipy dashboard app
│   │   ├── api.py          # FastAPI backend (future)
│   │   └── components/     # Reusable UI components
│   │       ├── __init__.py
│   │       ├── charts.py   # Plotly chart components
│   │       └── filters.py  # UI filter components
│   └── utils/
│       ├── __init__.py
│       ├── cache.py        # Caching utilities
│       └── logger.py       # Logging configuration
├── tests/
├── config/
│   └── subjects.yaml       # Subject/tag configurations
├── templates/
│   └── report.md.jinja2    # Report templates
└── examples/
    └── apache_flink.yaml   # Example configuration
```

### Data Flow

#### CLI Mode
1. **Input**: CLI parameters or configuration file
2. **API Client**: Authenticate and query Stack Exchange API
3. **Content Processor**: Clean and structure raw data
4. **Analyzer**: Generate metrics and insights
5. **Exporter**: Output in requested format(s)

#### Web UI Mode (`--ui`)
1. **Data Loading**: Load cached data or fetch from API
2. **Dashboard Startup**: Launch Streamlit web application
3. **Interactive Analysis**: Real-time filtering and visualization
4. **Live Updates**: Optional periodic data refresh
5. **Export from UI**: Download reports directly from web interface

### Configuration System

Tendance supports flexible configuration through YAML files, environment variables, and command-line arguments.

#### Quick Start
```bash
# Create example configuration
tendance config --create

# Show current configuration
tendance config --show

# Use configuration file
export CONFIG_FILE=tendance-config.yaml
tendance analyze --subject apache-flink
```

#### Configuration Structure
```yaml
# API settings
api:
  api_key: null  # Get from stackapps.com
  site: 'stackoverflow'
  default_page_size: 30
  max_pages_cli: 10

# Output settings
output:
  default_directory: './output'
  default_formats: ['json', 'csv']

# Subject definitions
subjects:
  apache-flink:
    name: 'Apache Flink'
    tags: ['apache-flink', 'flink-sql', 'flink-streaming']
    min_score: 0
```

#### Environment Variables
```bash
export TENDANCE_API__API_KEY="your_key"
export TENDANCE_OUTPUT__DEFAULT_DIRECTORY="/custom/path"
```

---

## 🚀 Usage Examples

### Installation with uv
```bash
# Install uv package manager (if not already installed)
curl -LsSf https://astral.sh/uv/install.sh | sh

# Clone and install the project
git clone <repository-url>
cd tools/

# Install core dependencies
uv sync

# Install with web UI support
uv sync --extra web

# Install development dependencies
uv sync --extra dev
```

### Basic CLI Usage

```bash
export CONFIG_FILE=./config/tendance-j9r.yaml

# Fetch Apache Flink content from 2024
uv run tendance --subject apache-flink --from-date 2024-01-01

# Use configuration file
uv run tendance --config config/apache_flink.yaml

# Export specific formats
uv run tendance analyze --subject apache-flink --from-date 2024-01-01 --output json
```

### Web UI Usage
```bash
# Launch interactive web dashboard
uv run tendance ui

# Launch with specific port
uv run tendance ui --port 3000

# Launch with configuration file  
uv run tendance ui --config config/apache_flink.yaml --port 3000
```

#### Web UI Features
- **📊 Dataset Management**: Load and visualize saved JSON datasets
- **📈 Interactive Tables**: Browse questions with sortable columns
- **📋 Statistics Dashboard**: View analysis summaries and metrics
- **🤖 RAG Chat Interface**: Chat interface ready for RAG system integration
- **🎯 Real-time Updates**: Dynamic dataset loading and visualization

### Advanced CLI Usage
```bash
# Multiple tags with custom output
uv run tendance analyze \
  --tags apache-flink,flink-sql,flink-streaming \
  --from-date 2024-01-01 \
  --min-score 5 \
  --output-dir ./flink-analysis \
  --formats json,markdown

# Extract comprehensive RAG knowledge base
uv run tendance analyze \
  --subject apache-flink \
  --from-date 2023-01-01 \
  --min-score 1 \
  --formats rag-jsonl,rag-text,rag-md \
  --output-dir ./flink-knowledge

# Configuration management
uv run tendance config --create
uv run tendance config --show
uv run tendance config --validate -f my-config.yaml

# Web interface for dataset visualization
uv run tendance ui --port 8501
```

---

## 📊 Expected Output

### JSON Export
```json
{
  "metadata": {
    "subject": "Apache Flink",
    "query_date": "2024-09-24T10:30:00Z",
    "date_range": {"from": "2024-01-01", "to": "2024-09-24"},
    "total_questions": 247,
    "total_answers": 891
  },
  "questions": [...],
  "summary": {
    "top_tags": ["apache-flink", "flink-sql", "streaming"],
    "monthly_counts": {...},
    "avg_score": 2.3
  }
}
```

### Markdown Report
- Executive summary with key metrics
- Top questions by score/views
- Monthly trend analysis
- Tag distribution
- Common problem patterns

### Web Dashboard (`--ui`)
The interactive web dashboard provides:

#### 📈 **Main Dashboard**
- **Overview Metrics**: Total questions, answers, trends at a glance
- **Interactive Timeline**: Plotly charts showing question volume over time
- **Tag Distribution**: Pie charts and bar graphs of popular tags
- **Score Analysis**: Distribution of question and answer scores

#### 🔍 **Filtering & Search**
- **Date Range Picker**: Filter content by specific date ranges
- **Tag Filters**: Multi-select tag filtering
- **Score Thresholds**: Filter by minimum scores
- **Content Type**: Questions, answers, or both

#### 📋 **Data Tables**
- **Questions Table**: Sortable, filterable list of questions
- **Answers Table**: Associated answers with acceptance status
- **Export Options**: Download filtered data as CSV/JSON
- **Pagination**: Handle large datasets efficiently

#### 🎯 **Advanced Analytics** (Future)
- **Trend Analysis**: Seasonal patterns and growth trends
- **Topic Clustering**: Automatic categorization of common themes
- **User Activity**: Top contributors and activity patterns
- **RAG Chat Interface**: Ask questions about the data using LLM integration

#### 🌐 **Web Features**
- **Responsive Design**: Works on desktop, tablet, and mobile
- **Real-time Updates**: Optional periodic data refresh
- **Bookmarkable URLs**: Share specific views and filters
- **Dark/Light Mode**: User preference themes

---

## 🔧 Development Roadmap

### Phase 1: MVP (Core Functionality)
- [ ] Basic CLI interface
- [ ] Stack Exchange API integration
- [ ] JSON/CSV export
- [ ] Apache Flink tag support
- [ ] Basic Streamlit web dashboard with `--ui` flag

### Phase 2: Enhanced Features
- [ ] Configuration file support
- [ ] Markdown report generation
- [ ] Content cleaning and analysis
- [ ] Error recovery and caching
- [ ] Interactive web dashboard with filtering
- [ ] Real-time data visualization with Plotly

### Phase 3: Advanced Analysis
- [ ] Trend analysis and metrics
- [ ] Multiple subject support
- [ ] Template system for custom reports
- [ ] Performance optimizations
- [ ] Advanced web features (FastAPI backend)
- [ ] Export functionality from web UI
- [ ] RAG integration for LLM-powered chat interface

---

## 📝 Notes & Considerations

### API Limitations
- Stack Exchange API rate limit: 30 requests/second
- Daily quota: 300 requests (no key) / 10,000 requests (with key)
- Some endpoints require authentication for full access

### Data Quality
- Stack Exchange content includes HTML that needs cleaning
- Some questions may be closed, deleted, or migrated
- Tag usage can vary and evolve over time

### Web UI Requirements
- Web dependencies are optional (`uv sync --extra web`)
- Streamlit dashboard runs on localhost:8501 by default
- Modern web browser required (Chrome, Firefox, Safari, Edge)
- Minimum 4GB RAM recommended for large datasets

### Compliance
- Respect Stack Exchange API terms of service
- Attribution requirements for content usage
- Consider data retention and privacy policies

### Development Setup
```bash
# Complete development setup with all extras
uv sync --all-extras

# Run tests
uv run pytest tests/ut

# Format code
uv run black .
uv run ruff check --fix .

# Type checking
uv run mypy src/tendance/
```

---

## 🤝 Contributing

We welcome contributions! Areas where you can help:
- Additional output formats
- New analysis metrics
- Performance improvements
- Documentation and examples
- Testing and validation

---

## 📄 License

Apache 2.0
