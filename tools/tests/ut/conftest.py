"""
Pytest configuration for unit tests
"""

import pytest
from pathlib import Path
import tempfile
import os


@pytest.fixture
def temp_config_file():
    """Create a temporary configuration file for testing"""
    with tempfile.NamedTemporaryFile(mode='w', suffix='.yaml', delete=False) as f:
        f.write("""
subject:
  name: "Test Subject"
  tags: ["test-tag", "another-tag"]
  sites: ["stackoverflow"]
  
query:
  from_date: "2024-01-01"
  to_date: null
  min_score: 0
  include_answers: true
  
output:
  formats: ["json", "csv"]
  directory: "./test_output"
  include_metrics: true
""")
        temp_file = f.name
    
    yield Path(temp_file)
    
    # Cleanup
    os.unlink(temp_file)


@pytest.fixture
def temp_output_dir():
    """Create a temporary output directory for testing"""
    with tempfile.TemporaryDirectory() as temp_dir:
        yield Path(temp_dir)
