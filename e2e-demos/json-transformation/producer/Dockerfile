FROM python:3.12-slim

# Set working directory
WORKDIR /app

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    libc6-dev \
    librdkafka-dev \
    pkg-config \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install UV and Python dependencies
COPY pyproject.toml ./
RUN curl -LsSf https://astral.sh/uv/install.sh | sh && \
    export PATH="/root/.cargo/bin:$HOME/.local/bin:$PATH" && \
    uv pip install --system --no-cache -r pyproject.toml

# Copy the application code
COPY . /app

# Create a non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser
RUN chown -R appuser:appuser /app
USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import confluent_kafka, pydantic; print('Dependencies OK')" || exit 1

# Command will be specified in Kubernetes pod specifications 