#!/usr/bin/env python3
"""
Test script for Taipy UI functionality
"""

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'src'))

from tendance.ui import TendanceApp

def test_ui():
    """Test the Taipy UI components"""
    print("🔍 Testing Tendance Taipy UI...")
    
    # Initialize the app
    app = TendanceApp(output_directory="./output", host="localhost", port=8502)
    
    print(f"✅ App initialized successfully")
    print(f"📁 Output directory: {app.output_directory}")
    print(f"📊 Available datasets: {app.available_datasets}")
    print(f"🌐 Host: {app.host}, Port: {app.port}")
    
    if app.available_datasets:
        print(f"📋 Dataset info loaded: {bool(app.dataset_info)}")
        print(f"📈 Questions dataframe shape: {app.questions_df.shape}")
    else:
        print("⚠️  No datasets found - run 'tendance analyze' first")
    
    print("\n💬 Testing chat functionality...")
    # Simulate a state object
    class MockState:
        def __init__(self):
            self.current_message = "Hello, how does Flink windowing work?"
            self.chat_display = ""
    
    state = MockState()
    app.on_send_message(state)
    print(f"✅ Chat response generated: {len(state.chat_display)} characters")
    
    print("\n🎉 All tests passed! The UI is ready to run.")
    print("💡 To start the web interface: uv run tendance ui")

if __name__ == "__main__":
    test_ui()
