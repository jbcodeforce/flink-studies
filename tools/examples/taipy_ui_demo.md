# Tendance Taipy Web UI Demo

## Overview

The Tendance Taipy web interface provides an interactive dashboard for visualizing Stack Exchange data and chatting with a RAG-powered assistant.

## Features

### 📊 Dataset Management
- **Automatic Dataset Discovery**: Scans the output directory for Tendance JSON files
- **Dynamic Loading**: Select and load different datasets on-the-fly
- **Dataset Information**: View metadata, statistics, and generation info

### 📈 Data Visualization  
- **Interactive Tables**: Sortable question listings with metadata
- **Question Details**: ID, title, score, views, answers, and status
- **Real-time Updates**: Data refreshes when switching datasets

### 🤖 RAG Chat Interface
- **Conversational UI**: Natural language chat interface
- **Mock Responses**: Demonstrates chat functionality with intelligent responses
- **RAG-Ready**: Prepared for integration with actual RAG systems
- **Chat History**: Persistent conversation tracking

## Getting Started

### 1. Generate Data
```bash
# Create sample dataset
uv run tendance analyze --subject apache-flink --from-date 2024-06-01 --formats json

# Or create RAG knowledge base
uv run tendance analyze --subject apache-flink --formats rag-jsonl,json
```

### 2. Install Web Dependencies  
```bash
uv sync --extra web
```

### 3. Launch Web Interface
```bash
# Default port (8501)
uv run tendance ui

# Custom port
uv run tendance ui --port 3000

# With configuration
uv run tendance ui --config my-config.yaml --port 8080
```

### 4. Access Dashboard
Open your browser to: `http://localhost:8501`

## UI Components

### Dataset Selector
- Dropdown menu with all available datasets
- Shows dataset name with timestamp
- Auto-loads first dataset on startup

### Statistics Panel
```
Dataset: apache-flink_20250923_213015
Total Questions: 2
Answered: 1
Average Score: 0.5
Generated: 2025-09-23T21:30:15.629743
```

### Questions Table
| ID | Title | Score | Views | Answers | Answered |
|----|-------|-------|-------|---------|----------|
| 79610784 | Issue while adding Tumble Window/Watermark... | 1 | 101 | 1 | ✅ |
| 79358905 | How to configure Flink streaming job... | 0 | 105 | 1 | ❌ |

### Chat Interface
```
You: Hello, how does Flink windowing work?

Flink Assistant: 👋 Hello! I'm your Flink assistant. 
Apache Flink is a powerful stream processing framework. 
What specific aspect would you like to know about?

You: Tell me about watermarks

Flink Assistant: Watermarks in Apache Flink are crucial for event time processing:

Key concepts:
- Watermarks indicate progress in event time
- They trigger window computations  
- Handle out-of-order events

Would you like specific examples of window configurations?
```

## Architecture

### State Management
- **Reactive Updates**: UI automatically updates when data changes
- **Component Binding**: Taipy handles state synchronization
- **Event Handlers**: Custom functions for user interactions

### Data Flow
1. **Dataset Discovery**: Scans output directory for JSON files
2. **Dataset Loading**: Parses JSON and converts to DataFrame
3. **UI Rendering**: Taipy renders components with current state
4. **User Interaction**: Events trigger state updates and re-rendering

### Integration Points
- **CLI Integration**: Seamlessly launched via `tendance ui`
- **Configuration System**: Uses Tendance config for defaults
- **RAG Preparation**: Chat interface ready for RAG system connection

## Future RAG Integration

The chat interface is designed for easy RAG system integration:

```python
def connect_rag_system(self, rag_client):
    """Connect actual RAG system"""
    self.rag_client = rag_client
    
def on_send_message(self, state):
    """Enhanced with RAG"""
    user_msg = state.current_message.strip()
    
    # Query RAG system with Stack Exchange knowledge
    rag_response = self.rag_client.query(
        question=user_msg,
        knowledge_base="stack_exchange_flink",
        max_tokens=500
    )
    
    # Update chat with RAG response
    self.update_chat(user_msg, rag_response)
```

## Customization

### Themes and Styling
Taipy supports custom CSS and themes:
```python
gui.run(
    theme="dark",
    custom_css="path/to/custom.css"
)
```

### Additional Charts
Add more visualizations:
```python
def create_timeline_chart(self, df):
    """Create question timeline"""
    return px.scatter(df, x='creation_date', y='score', 
                     hover_data=['title'], 
                     title='Question Timeline')
```

### Custom Components
Extend with custom Taipy components:
```python
# Custom filter component
filter_layout = """
<|{tag_filter}|selector|lov={available_tags}|multiple=True|>
<|{date_range}|date_range|>
"""
```

## Troubleshooting

### Common Issues

1. **No datasets found**
   ```bash
   # Generate data first
   uv run tendance analyze --subject apache-flink --formats json
   ```

2. **Port already in use**
   ```bash
   # Use different port
   uv run tendance ui --port 8502
   ```

3. **Web dependencies not installed**
   ```bash
   uv sync --extra web
   ```

### Debug Mode
```bash
# Enable debug logging
TENDANCE_LOGGING__LEVEL=DEBUG uv run tendance ui
```

## Next Steps

1. **Connect RAG System**: Integrate with LangChain, LlamaIndex, or custom RAG
2. **Add Visualizations**: Charts for trends, user activity, tag evolution  
3. **Export Features**: Direct export from UI to various formats
4. **User Management**: Session handling and user preferences
5. **Real-time Updates**: Live data streaming and automatic refresh
