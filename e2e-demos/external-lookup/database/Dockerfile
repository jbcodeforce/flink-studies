# DuckDB External Lookup Database Container
# This container initializes a DuckDB database with claims data for the external lookup demo

FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    openjdk-11-jre-headless \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Install DuckDB CLI - detect architecture and download appropriate binary
RUN ARCH=$(dpkg --print-architecture) \
    && echo "Detected architecture: $ARCH" \
    && if [ "$ARCH" = "amd64" ]; then \
        DUCKDB_ARCH="linux-amd64"; \
    elif [ "$ARCH" = "arm64" ]; then \
        DUCKDB_ARCH="linux-aarch64"; \
    else \
        echo "Unsupported architecture: $ARCH"; \
        exit 1; \
    fi \
    && echo "Downloading DuckDB for: $DUCKDB_ARCH" \
    && curl -L https://github.com/duckdb/duckdb/releases/download/v1.1.3/duckdb_cli-${DUCKDB_ARCH}.zip -o duckdb.zip \
    && unzip duckdb.zip \
    && mv duckdb /usr/local/bin/ \
    && rm duckdb.zip \
    && chmod +x /usr/local/bin/duckdb

# Install Python DuckDB for HTTP API wrapper
RUN pip3 install duckdb==1.1.3 fastapi==0.104.1 uvicorn==0.24.0 pydantic==2.5.0

# Create app directory
WORKDIR /app


# Create data directory
RUN mkdir -p /data

# Copy SQL scripts
COPY 01_create_schema.sql .
COPY 02_insert_data.sql .

# Copy HTTP API wrapper script
COPY claimdb_api.py .

# Create database initialization script
RUN echo '#!/bin/bash\n\
set -e\n\
echo "Initializing DuckDB database..."\n\
echo "Creating database directory..."\n\
mkdir -p /data\n\
echo "Running schema creation..."\n\
if duckdb /data/claims.db < 01_create_schema.sql; then\n\
    echo "Schema creation successful"\n\
else\n\
    echo "Schema creation failed"\n\
    exit 1\n\
fi\n\
echo "Inserting data..."\n\
if duckdb /data/claims.db < 02_insert_data.sql; then\n\
    echo "Data insertion successful"\n\
else\n\
    echo "Data insertion failed"\n\
    exit 1\n\
fi\n\
echo "Verifying database exists..."\n\
if [ -f "/data/claims.db" ]; then\n\
    echo "Database file exists: $(ls -la /data/claims.db)"\n\
else\n\
    echo "ERROR: Database file does not exist!"\n\
    exit 1\n\
fi\n\
echo "Database initialized successfully"\n\
echo "Starting ClaimDB HTTP API..."\n\
python3 claimdb_api.py' > init_and_serve.sh && chmod +x init_and_serve.sh


# Expose port for HTTP API
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Run initialization and API server
CMD ["./init_and_serve.sh"]
