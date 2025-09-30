
FROM python:3.12-slim

# Set working directory
WORKDIR /app

ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy pyproject.toml first for better layer caching
COPY pyproject.toml ./

# Install uv and Python dependencies  
RUN curl -LsSf https://astral.sh/uv/install.sh | sh && \
    export PATH="/root/.cargo/bin:$HOME/.local/bin:$PATH" && \
    uv pip install --system --no-cache -r pyproject.toml

# Copy source code
COPY . /app

# Install the package itself to make payment-generator CLI available
RUN export PATH="/root/.cargo/bin:$HOME/.local/bin:$PATH" && \
    uv pip install --system --no-deps -e .

# Create non-root user
RUN groupadd -r eventgen && useradd -r -g eventgen eventgen
RUN chown -R eventgen:eventgen /app


# Create directories for logs and configuration
RUN mkdir -p /app/logs /app/config

# Copy entrypoint script
COPY docker-entrypoint.sh ./
RUN chmod +x docker-entrypoint.sh && \
    chown eventgen:eventgen docker-entrypoint.sh

# Expose metrics port
EXPOSE 8090

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8090/metrics || exit 1

# Set default environment variables
ENV PAYMENT_GEN_LOG_LEVEL=INFO \
    PAYMENT_GEN_ENABLE_METRICS=true \
    PAYMENT_GEN_METRICS_PORT=8090 \
    PAYMENT_GEN_KAFKA_BOOTSTRAP_SERVERS=kafka:9092 \
    PAYMENT_GEN_KAFKA_TOPIC=payment-events \
    PAYMENT_GEN_EVENTS_PER_SECOND=10.0

USER eventgen
# Default command
ENTRYPOINT ["./docker-entrypoint.sh"]
CMD ["generate", "--rate", "10", "--duration", "0"]

