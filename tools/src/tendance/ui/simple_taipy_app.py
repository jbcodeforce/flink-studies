
"""
Simple Tendance Taipy Application - Testing Version

A simplified version to test Taipy integration before building the full app.
"""

import json
import logging
from pathlib import Path
from typing import Dict, List, Optional, Any
import pandas as pd

from taipy.gui import Gui, Markdown
import plotly.graph_objects as go
import plotly.express as px

logger = logging.getLogger(__name__)


class SimpleTendanceApp:
    """Simple Tendance Taipy Application for testing"""
    
    def __init__(self, output_directory: str = "./output", host: str = "localhost", port: int = 8501):
        self.host = host
        self.port = port
        self.output_directory = Path(output_directory)
        
        # Initialize state
        self.available_datasets = self._scan_datasets()
        self.selected_dataset = self.available_datasets[0] if self.available_datasets else ""
        self.dataset_info = ""
        self.questions_df = pd.DataFrame()
        self.current_message = ""
        self.chat_messages = []
        self.chat_display = "Welcome! Ask me about Apache Flink."
        
        # Load first dataset if available
        if self.selected_dataset:
            self._load_dataset(self.selected_dataset)
    
    def _scan_datasets(self) -> List[str]:
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
                    
            except Exception:
                pass
        
        return sorted(dataset_names)
    
    def _load_dataset(self, dataset_name: str) -> None:
        """Load a specific dataset"""
        file_path = self.output_directory / f"{dataset_name}.json"
        
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
            
            # Extract basic info
            stats = data.get('statistics', {})
            metadata = data.get('metadata', {})
            
            self.dataset_info = f"""**Dataset**: {dataset_name}
**Total Questions**: {stats.get('total_questions', 0)}
**Answered**: {stats.get('answered_questions', 0)}
**Average Score**: {stats.get('score_statistics', {}).get('average', 0):.1f}
**Generated**: {metadata.get('generated_at', 'Unknown')}"""
            
            # Convert questions to DataFrame
            questions = data.get('questions', [])
            df_data = []
            
            for q in questions:
                df_data.append({
                    'ID': q.get('question_id', ''),
                    'Title': q.get('title', '')[:80] + ('...' if len(q.get('title', '')) > 80 else ''),
                    'Score': q.get('score', 0),
                    'Views': q.get('view_count', 0),
                    'Answers': q.get('answer_count', 0),
                    'Answered': '✅' if q.get('is_answered', False) else '❌',
                })
            
            self.questions_df = pd.DataFrame(df_data)
            logger.info(f"Loaded dataset: {dataset_name} with {len(df_data)} questions")
            
        except Exception as e:
            logger.error(f"Failed to load dataset {dataset_name}: {e}")
            self.dataset_info = f"**Error loading dataset**: {dataset_name}"
            self.questions_df = pd.DataFrame()
    
    def on_dataset_change(self, state):
        """Handle dataset selection change"""
        if hasattr(state, 'selected_dataset') and state.selected_dataset:
            self._load_dataset(state.selected_dataset)
            state.dataset_info = self.dataset_info
            state.questions_df = self.questions_df
    
    def on_send_message(self, state):
        """Handle chat message sending"""
        if hasattr(state, 'current_message') and state.current_message.strip():
            user_msg = state.current_message.strip()
            
            # Simple mock responses
            if 'hello' in user_msg.lower() or 'hi' in user_msg.lower():
                bot_response = "👋 Hello! I'm your Flink assistant. I can help with Apache Flink questions!"
            elif 'flink' in user_msg.lower():
                bot_response = "Apache Flink is a powerful stream processing framework. What specific aspect would you like to know about?"
            elif 'help' in user_msg.lower():
                bot_response = "I can help you with:\n• Flink concepts\n• Stream processing\n• Window operations\n• Watermarks\n\nWhat interests you?"
            else:
                bot_response = f"Interesting question about '{user_msg}'. The full RAG system will provide detailed answers based on Stack Exchange data!"
            
            # Add to chat history
            self.chat_messages.append({
                'user': user_msg,
                'bot': bot_response
            })
            
            # Update chat display
            chat_text = []
            for i, msg in enumerate(self.chat_messages):
                chat_text.append(f"**You**: {msg['user']}")
                chat_text.append(f"**Flink Assistant**: {msg['bot']}")
                if i < len(self.chat_messages) - 1:
                    chat_text.append("---")
            
            state.chat_display = "\n\n".join(chat_text) if chat_text else "No messages yet."
            state.current_message = ""
    
    def run(self):
        """Run the simple Taipy application"""
        
        # Simple page layout
        page = """
# 🔍 Tendance - Stack Exchange Analytics

## 📊 Dataset Viewer

**Select Dataset**: <|{selected_dataset}|selector|lov={available_datasets}|on_change=on_dataset_change|>

<|{dataset_info}|text|>

<|{questions_df}|table|>

---

## 🤖 Chat with Flink Assistant

**Your Question**: <|{current_message}|input|>
<|Send|button|on_action=on_send_message|>

### Chat History
<|{chat_display}|text|>

---
**System Info**: Running on {host}:{port} | Datasets: {len(available_datasets)}
"""

        # Create and run GUI
        gui = Gui(page=page)
        
        logger.info(f"Starting Simple Taipy app on {self.host}:{self.port}")
        logger.info(f"Available datasets: {self.available_datasets}")
        
        gui.run(
            host=self.host,
            port=self.port,
            debug=True,
            title="Tendance - Stack Exchange Analytics"
        )
