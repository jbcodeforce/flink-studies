#!/bin/bash
# Test runner script for Tendance project

set -e

echo "🧪 Running Tendance CLI Tests"
echo "=========================="

# Check if uv is available
if ! command -v uv &> /dev/null; then
    echo "❌ Error: uv is not installed. Please install uv first."
    exit 1
fi

# Install test dependencies
echo "📦 Installing dependencies..."
uv sync --extra dev

# Run tests with coverage
echo "🔍 Running unit tests with coverage..."
uv run pytest tests/ut/ -v --cov=tendance --cov-report=term-missing --cov-report=html

echo "✅ Tests completed successfully!"
echo "📊 Coverage report available in htmlcov/index.html"
