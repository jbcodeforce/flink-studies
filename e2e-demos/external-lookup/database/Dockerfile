# PostgreSQL External Lookup Database Container
# This container initializes a PostgreSQL database with claims data for the external lookup demo

FROM postgres:16-alpine

# Install additional dependencies
RUN apk add --no-cache \
    python3 \
    py3-pip \
    curl \
    gcc \
    python3-dev \
    musl-dev \
    libpq-dev

# Create app directory
WORKDIR /app

ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV VIRTUAL_ENV=/app/venv
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

# Create virtual environment
RUN python3 -m venv $VIRTUAL_ENV

# Copy project files first for better layer caching
COPY pyproject.toml .
COPY claimdb_api.py .

# Install uv and Python dependencies  
RUN curl -LsSf https://astral.sh/uv/install.sh | sh && \
    export PATH="/root/.cargo/bin:$HOME/.local/bin:$PATH" && \
    . $VIRTUAL_ENV/bin/activate && \
    $HOME/.local/bin/uv pip install --no-cache pyproject.toml

# Copy SQL scripts
COPY 01_create_schema.sql /docker-entrypoint-initdb.d/01_create_schema.sql
COPY 02_insert_data.sql /docker-entrypoint-initdb.d/02_insert_data.sql

# Set PostgreSQL environment variables
ENV POSTGRES_DB=claims
ENV POSTGRES_USER=claims_user
ENV POSTGRES_PASSWORD=claims_password
ENV PGDATA=/data

# Create database initialization script
COPY <<EOF /docker-entrypoint-initdb.d/00_init.sh
#!/bin/sh
set -e

echo "PostgreSQL initialization script running..."

# Create claims database and user if they don't exist
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE USER $POSTGRES_USER WITH PASSWORD '$POSTGRES_PASSWORD';
    CREATE DATABASE $POSTGRES_DB;
    GRANT ALL PRIVILEGES ON DATABASE $POSTGRES_DB TO $POSTGRES_USER;
EOSQL

echo "Database initialization completed"
EOF

RUN chmod +x /docker-entrypoint-initdb.d/00_init.sh

# Create API startup script
RUN echo '#!/bin/sh\n\
set -e\n\
\n\
echo "Starting ClaimDB HTTP API..."\n\
. $VIRTUAL_ENV/bin/activate\n\
python3 -m uvicorn claimdb_api:app --host 0.0.0.0 --port 8080' > /app/start_api.sh && chmod +x /app/start_api.sh

# Create non-root user for API
RUN addgroup -S apiuser && adduser -S apiuser -G apiuser
RUN chown -R apiuser:apiuser /app

# Expose port for HTTP API and PostgreSQL
EXPOSE 8080 5432

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Use the official PostgreSQL entrypoint script
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# Start both PostgreSQL and the API server
CMD ["postgres", "-c", "config_file=/etc/postgresql/postgresql.conf"]