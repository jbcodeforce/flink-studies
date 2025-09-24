
"""
Tendance Taipy Web Application

This module provides a modern web interface for Tendance using Taipy,
including dataset visualization and RAG chat functionality.
"""

import json
import logging
from pathlib import Path
from typing import Dict, List, Optional, Any
from datetime import datetime
import pandas as pd

from taipy import Config, Core, Gui
from taipy.gui import Markdown
import plotly.graph_objects as go
import plotly.express as px

logger = logging.getLogger(__name__)


class DatasetManager:
    """Manages dataset loading and processing for the UI"""
    
    def __init__(self, output_directory: str = "./output"):
        self.output_directory = Path(output_directory)
        self.datasets: Dict[str, Dict] = {}
        self.current_dataset: Optional[str] = None
        
    def scan_datasets(self) -> List[str]:
        """Scan for available JSON datasets"""
        if not self.output_directory.exists():
            return []
        
        json_files = list(self.output_directory.glob("*.json"))
        dataset_names = []
        
        for file_path in json_files:
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                    
                # Check if it's a Tendance dataset
                if 'metadata' in data and 'questions' in data:
                    dataset_names.append(file_path.stem)
                    logger.info(f"Found dataset: {file_path.stem}")
                    
            except Exception as e:
                logger.warning(f"Failed to load {file_path}: {e}")
        
        return sorted(dataset_names)
    
    def load_dataset(self, dataset_name: str) -> bool:
        """Load a specific dataset"""
        file_path = self.output_directory / f"{dataset_name}.json"
        
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
            
            self.datasets[dataset_name] = data
            self.current_dataset = dataset_name
            logger.info(f"Loaded dataset: {dataset_name}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to load dataset {dataset_name}: {e}")
            return False
    
    def get_current_data(self) -> Optional[Dict]:
        """Get the currently loaded dataset"""
        if self.current_dataset and self.current_dataset in self.datasets:
            return self.datasets[self.current_dataset]
        return None
    
    def get_questions_dataframe(self) -> pd.DataFrame:
        """Convert questions to pandas DataFrame for visualization"""
        data = self.get_current_data()
        if not data or 'questions' not in data:
            return pd.DataFrame()
        
        questions = data['questions']
        df_data = []
        
        for q in questions:
            df_data.append({
                'question_id': q.get('question_id', ''),
                'title': q.get('title', '')[:100] + ('...' if len(q.get('title', '')) > 100 else ''),
                'tags': ', '.join(q.get('tags', [])),
                'score': q.get('score', 0),
                'view_count': q.get('view_count', 0),
                'answer_count': q.get('answer_count', 0),
                'is_answered': q.get('is_answered', False),
                'creation_date': q.get('creation_date', ''),
                'link': q.get('link', '')
            })
        
        return pd.DataFrame(df_data)
    
    def get_statistics(self) -> Dict[str, Any]:
        """Get dataset statistics"""
        data = self.get_current_data()
        if not data:
            return {}
        
        stats = data.get('statistics', {})
        metadata = data.get('metadata', {})
        
        return {
            'total_questions': stats.get('total_questions', 0),
            'answered_questions': stats.get('answered_questions', 0),
            'answer_rate': stats.get('answer_rate', 0) * 100,
            'avg_score': stats.get('score_statistics', {}).get('average', 0),
            'total_views': stats.get('view_statistics', {}).get('total', 0),
            'generated_at': metadata.get('generated_at', ''),
            'tool_version': metadata.get('tool_version', ''),
        }


class RAGChatManager:
    """Manages RAG chat functionality"""
    
    def __init__(self):
        self.chat_history: List[Dict[str, str]] = []
        self.rag_enabled = False  # Future: connect to actual RAG system
    
    def add_message(self, user_message: str, bot_response: str = None):
        """Add a message to chat history"""
        if bot_response is None:
            bot_response = self._generate_mock_response(user_message)
        
        self.chat_history.append({
            'timestamp': datetime.now().isoformat(),
            'user': user_message,
            'bot': bot_response
        })
    
    def _generate_mock_response(self, message: str) -> str:
        """Generate mock responses for demonstration"""
        message_lower = message.lower()
        
        if 'flink' in message_lower and 'window' in message_lower:
            return """Based on the Stack Exchange knowledge base, here are key points about Flink windowing:

🔹 **Tumbling Windows**: Fixed-size, non-overlapping windows
🔹 **Sliding Windows**: Fixed-size, overlapping windows  
🔹 **Session Windows**: Dynamic windows based on activity gaps

**Common issues**:
- Watermark configuration for event time processing
- Late data handling with allowed lateness
- Window trigger customization

Would you like specific examples of window configurations?"""
        
        elif 'watermark' in message_lower:
            return """Watermarks in Apache Flink are crucial for event time processing:

**Key concepts**:
- Watermarks indicate progress in event time
- They trigger window computations
- Handle out-of-order events

**Configuration example**:
```java
WatermarkStrategy.forBoundedOutOfOrderness(Duration.ofSeconds(5))
```

This allows events to be up to 5 seconds late before the window closes."""
        
        elif any(word in message_lower for word in ['hello', 'hi', 'help']):
            return """👋 Hello! I'm your Flink knowledge assistant.

I can help you with:
• Apache Flink concepts and best practices
• Stream processing patterns
• Window operations and watermarks  
• Table API and Flink SQL
• Troubleshooting common issues

**Note**: This is a demo interface. The full RAG system will be integrated to provide answers based on the actual Stack Exchange knowledge base.

What would you like to learn about Flink?"""
        
        else:
            return f"""I understand you're asking about: "{message}"

**🚧 RAG System Coming Soon**: This chat interface is ready for integration with a full RAG (Retrieval Augmented Generation) system that will:

• Search through extracted Stack Exchange knowledge
• Provide accurate, context-aware answers
• Reference original sources
• Learn from the community's expertise

For now, I can provide general guidance about Apache Flink topics. What specific area interests you?"""
    
    def get_formatted_history(self) -> str:
        """Get formatted chat history for display"""
        if not self.chat_history:
            return "💬 **Chat History**: No messages yet. Start by saying hello!"
        
        formatted = []
        for entry in self.chat_history:
            timestamp = datetime.fromisoformat(entry['timestamp']).strftime('%H:%M:%S')
            formatted.append(f"**You** ({timestamp}): {entry['user']}")
            formatted.append(f"**Flink Assistant**: {entry['bot']}")
            formatted.append("---")
        
        return "\n\n".join(formatted)


class TendanceApp:
    """Main Tendance Taipy Application"""
    
    def __init__(self, output_directory: str = "./output", host: str = "localhost", port: int = 8501):
        self.host = host
        self.port = port
        self.dataset_manager = DatasetManager(output_directory)
        self.rag_chat = RAGChatManager()
        
        # Initialize UI state variables  
        self.available_datasets = self.dataset_manager.scan_datasets()
        self.selected_dataset = ""
        self.current_message = ""
        self.dataset_loaded = False
        
        # Data for visualization
        self.questions_df = pd.DataFrame()
        self.stats = {}
        self.score_chart = go.Figure()
        self.tags_chart = go.Figure()
        self.chat_history = ""
        self.dataset_directory = str(output_directory)
        self.chat_count = 0
        
    def refresh_datasets(self, state):
        """Refresh available datasets"""
        state.available_datasets = self.dataset_manager.scan_datasets()
        logger.info(f"Found {len(state.available_datasets)} datasets")
    
    def load_selected_dataset(self, state):
        """Load the selected dataset"""
        if state.selected_dataset:
            success = self.dataset_manager.load_dataset(state.selected_dataset)
            if success:
                state.dataset_loaded = True
                state.questions_df = self.dataset_manager.get_questions_dataframe()
                state.stats = self.dataset_manager.get_statistics()
                state.score_chart = self.create_score_distribution_chart(state.questions_df)
                state.tags_chart = self.create_tags_chart(state.questions_df)
                logger.info(f"Loaded dataset: {state.selected_dataset}")
            else:
                state.dataset_loaded = False
                logger.error(f"Failed to load dataset: {state.selected_dataset}")
    
    def send_message(self, state):
        """Send a chat message"""
        if state.current_message.strip():
            self.rag_chat.add_message(state.current_message.strip())
            state.current_message = ""  # Clear input
            state.chat_history = self.rag_chat.get_formatted_history()
            state.chat_count = len(self.rag_chat.chat_history)
            logger.info(f"Chat message sent, history length: {len(self.rag_chat.chat_history)}")
    
    def create_score_distribution_chart(self, df: pd.DataFrame):
        """Create score distribution chart"""
        if df.empty:
            return go.Figure()
        
        fig = px.histogram(df, x='score', nbins=20, title='Question Score Distribution')
        fig.update_layout(xaxis_title='Score', yaxis_title='Count')
        return fig
    
    def create_tags_chart(self, df: pd.DataFrame):
        """Create top tags chart"""
        if df.empty:
            return go.Figure()
        
        # Extract and count tags
        all_tags = []
        for tags_str in df['tags']:
            if tags_str:
                all_tags.extend([tag.strip() for tag in tags_str.split(',')])
        
        from collections import Counter
        tag_counts = Counter(all_tags)
        top_tags = dict(tag_counts.most_common(10))
        
        if not top_tags:
            return go.Figure()
        
        fig = px.bar(x=list(top_tags.keys()), y=list(top_tags.values()), title='Top Tags')
        fig.update_layout(xaxis_title='Tags', yaxis_title='Question Count')
        return fig
    
    def run(self):
        """Run the Taipy application"""
        
        # Define the UI layout with proper Taipy syntax
        page_layout = Markdown("""
# 🔍 Tendance - Stack Exchange Analytics

## 📊 Dataset Management

<|{selected_dataset}|selector|lov={available_datasets}|label=Select Dataset|>

<|Refresh Datasets|button|on_action=refresh_datasets|>

<|part|render={dataset_loaded}|
## 📈 Dataset Overview

### Statistics
**Total Questions**: {stats[total_questions] if stats else 0}  
**Answered**: {stats[answered_questions] if stats else 0} ({stats[answer_rate]:.1f if stats else 0}%)  
**Average Score**: {stats[avg_score]:.1f if stats else 0}  
**Total Views**: {stats[total_views]:,d if stats else 0}  

### Questions Table
<|{questions_df}|table|width=100%|height=400px|>

### Visualizations  
<|{score_chart}|chart|>
<|{tags_chart}|chart|>
|>

---

## 🤖 RAG Chat Interface

### Ask about Apache Flink
<|{current_message}|input|label=Your question|>
<|Send Message|button|on_action=send_message|>

### Chat History
<|{chat_history}|text|mode=markdown|>

---

## 🔧 System Info
**Host**: {host}:{port}  
**Dataset Directory**: {dataset_directory}  
**Chat Messages**: {chat_count}
""")

        # Create GUI with proper state binding
        gui = Gui(page_layout)
        
        # Set up initial state
        state_vars = {
            'available_datasets': self.available_datasets,
            'selected_dataset': self.selected_dataset,
            'current_message': self.current_message,
            'dataset_loaded': self.dataset_loaded,
            'questions_df': self.questions_df,
            'stats': self.stats,
            'score_chart': self.score_chart,
            'tags_chart': self.tags_chart,
            'chat_history': self.chat_history,
            'host': self.host,
            'port': self.port,
            'dataset_directory': self.dataset_directory,
            'chat_count': self.chat_count
        }
        
        logger.info(f"Starting Taipy app on {self.host}:{self.port}")
        logger.info(f"Found {len(self.available_datasets)} datasets: {self.available_datasets}")
        
        # Run the application
        gui.run(
            host=self.host,
            port=self.port,
            debug=False,
            use_reloader=False,
            **state_vars
        )


def create_app(output_directory: str = "./output", host: str = "localhost", port: int = 8501) -> TendanceApp:
    """Create a Tendance Taipy application instance"""
    return TendanceApp(output_directory, host, port)
