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
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir confluent-kafka>=2.11.1 pydantic>=2.11.7 fastapi>=0.104.0 uvicorn>=0.24.0 jinja2>=3.1.0 python-multipart>=0.0.6

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