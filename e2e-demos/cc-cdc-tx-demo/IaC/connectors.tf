# -----------------------------------------------------------------------------
# Connectors Configuration
# Card Transaction Processing Demo
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Pre-creation Schema Cleanup
# -----------------------------------------------------------------------------
# Delete any existing schemas before connector creation to avoid compatibility issues
# This ensures a clean slate when deploying or redeploying the connector
resource "null_resource" "pre_cleanup_cdc_schemas" {
  # Force this to run every time before connector creation
  # This ensures schemas are always cleaned up right before connector creation
  triggers = {
    prefix = var.prefix
    schema_registry_endpoint = data.confluent_schema_registry_cluster.card_tx_sr.rest_endpoint
    schema_registry_key_id = confluent_api_key.app_manager_sr_key.id
    # Force recreation every time by including timestamp
    # This ensures cleanup always runs before connector creation
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      
      SR_ENDPOINT="${data.confluent_schema_registry_cluster.card_tx_sr.rest_endpoint}"
      SR_KEY_ID="${confluent_api_key.app_manager_sr_key.id}"
      PREFIX="${var.prefix}"
      
      # Try to get Schema Registry API secret
      SR_SECRET=""
      if [ -n "${confluent_api_key.app_manager_sr_key.secret}" ]; then
        SR_SECRET="${confluent_api_key.app_manager_sr_key.secret}"
      elif [ -n "$SCHEMA_REGISTRY_API_SECRET" ]; then
        SR_SECRET="$SCHEMA_REGISTRY_API_SECRET"
      elif command -v terraform &> /dev/null; then
        TERRAFORM_OUTPUT=$(terraform output -raw schema_registry_api_secret 2>/dev/null || echo "")
        if [ -n "$TERRAFORM_OUTPUT" ]; then
          SR_SECRET="$TERRAFORM_OUTPUT"
        fi
      fi
      
      if [ -z "$SR_SECRET" ]; then
        echo "ERROR: Could not obtain Schema Registry API secret."
        echo "Please set SCHEMA_REGISTRY_API_SECRET environment variable or ensure"
        echo "terraform output schema_registry_api_secret is available."
        exit 1
      fi
      
      # Function to delete a schema subject
      delete_schema() {
        local subject=$1
        echo "Checking for existing schema: $subject"
        
        # Check if subject exists
        HTTP_CODE=$(curl -s -w "\n%%{http_code}" -u "$SR_KEY_ID:$SR_SECRET" \
          "$SR_ENDPOINT/subjects/$subject/versions" \
          -H "Content-Type: application/vnd.schemaregistry.v1+json" 2>/dev/null | tail -n1 || echo "404")
        
        if [ "$HTTP_CODE" = "200" ]; then
          echo "Deleting existing schema subject: $subject"
          DELETE_CODE=$(curl -s -w "\n%%{http_code}" -u "$SR_KEY_ID:$SR_SECRET" \
            -X DELETE \
            "$SR_ENDPOINT/subjects/$subject?permanent=true" \
            -H "Content-Type: application/vnd.schemaregistry.v1+json" 2>/dev/null | tail -n1 || echo "000")
          
          if [ "$DELETE_CODE" = "200" ] || [ "$DELETE_CODE" = "404" ]; then
            echo "Successfully deleted schema subject: $subject"
          else
            echo "Warning: Failed to delete schema subject $subject (HTTP $DELETE_CODE)"
          fi
        else
          echo "Schema subject $subject does not exist, skipping"
        fi
      }
      
      # Delete all CDC schemas if they exist
      # Use $$ to escape $ for shell variable expansion in Terraform heredoc
      echo "Deleting any existing schemas to ensure compatibility..."
      delete_schema "$${PREFIX}.public.customers-key"
      delete_schema "$${PREFIX}.public.customers-value"
      delete_schema "$${PREFIX}.public.transactions-key"
      delete_schema "$${PREFIX}.public.transactions-value"
      
      # Wait a moment to ensure Schema Registry has processed the deletions
      sleep 2
      
      # Verify schemas are deleted
      echo "Verifying schemas are deleted..."
      for subject in "$${PREFIX}.public.customers-key" "$${PREFIX}.public.customers-value" "$${PREFIX}.public.transactions-key" "$${PREFIX}.public.transactions-value"; do
        CHECK_CODE=$(curl -s -w "\n%%{http_code}" -u "$SR_KEY_ID:$SR_SECRET" \
          "$SR_ENDPOINT/subjects/$subject/versions" \
          -H "Content-Type: application/vnd.schemaregistry.v1+json" 2>/dev/null | tail -n1 || echo "404")
        if [ "$CHECK_CODE" = "404" ]; then
          echo "✓ Schema $subject confirmed deleted"
        else
          echo "⚠ Warning: Schema $subject still exists (HTTP $CHECK_CODE)"
        fi
      done
      
      echo "Pre-creation schema cleanup completed"
    EOT
  }

  depends_on = [
    confluent_api_key.app_manager_sr_key,
    data.confluent_schema_registry_cluster.card_tx_sr
  ]
}

# -----------------------------------------------------------------------------
# CDC Debezium v2 Source Connector
# -----------------------------------------------------------------------------
resource "confluent_connector" "card_tx_cdc_source" {
  environment {
    id = confluent_environment.card_tx_env.id
  }

  kafka_cluster {
    id = confluent_kafka_cluster.card_tx_cluster.id
  }

  config_sensitive = {
    "database.password" = var.db_password
  }

  config_nonsensitive = {
    # Connector identification
    "connector.class" = "PostgresCdcSourceV2"
    "name"            = "${var.prefix}-cdc-source"

    # Authentication
    "kafka.auth.mode"          = "SERVICE_ACCOUNT"
    "kafka.service.account.id" = confluent_service_account.connectors.id

    # Database connection
    "database.hostname"    = aws_db_instance.card_tx_db.address
    "database.port"        = tostring(aws_db_instance.card_tx_db.port)
    "database.user"        = var.db_username
    "database.dbname"      = aws_db_instance.card_tx_db.db_name
    "database.server.name" = var.prefix

    # Topic configuration
    # NOTE: Let Debezium create topics automatically to avoid schema compatibility issues
    # Topics will be created as: {prefix}.public.customers and {prefix}.public.transactions
    "topic.prefix" = var.prefix

    # CDC behavior
    "after.state.only"  = "false"  # Only emit the 'after' state, not full envelope
    "plugin.name"       = "pgoutput"  # PostgreSQL native logical replication

    # Output format
    "output.data.format" = "AVRO"
    "output.key.format"  = "AVRO"

    # Table filtering - only capture customers and transactions
    "table.include.list" = "public.customers,public.transactions"

    # Performance settings
    "tasks.max"           = "1"
    "time.precision.mode" = "connect"

    # Encryption visibility
    "csfle.configs.visible" = "false"
  }

  depends_on = [
    confluent_kafka_acl.connectors_describe_cluster,
    confluent_kafka_acl.connectors_write_topic,
    confluent_kafka_acl.connectors_create_topic,
    confluent_kafka_acl.connectors_read_topic,
    null_resource.pre_cleanup_cdc_schemas,  # Clean up schemas before connector creation
    aws_db_instance.card_tx_db
  ]

  lifecycle {
    prevent_destroy = false
  }
}

# -----------------------------------------------------------------------------
# Schema Registry Schema Cleanup
# -----------------------------------------------------------------------------
# Debezium CDC connector automatically creates Avro schemas in Schema Registry
# for both key and value of each topic. This resource ensures schemas are
# deleted when the connector is destroyed.
#
# Schemas created by Debezium:
# - {prefix}.public.customers-key
# - {prefix}.public.customers-value
# - {prefix}.public.transactions-key
# - {prefix}.public.transactions-value
resource "null_resource" "cleanup_cdc_schemas" {
  # Store only values that can be computed from variables (no resource references)
  # Resource references in triggers cause issues with destroy-time provisioners
  triggers = {
    # Store schema subject names (computed from prefix variable only)
    # No resource references allowed here for destroy-time provisioners
    customers_schema_key = "${var.prefix}.public.customers-key"
    customers_schema_value = "${var.prefix}.public.customers-value"
    transactions_schema_key = "${var.prefix}.public.transactions-key"
    transactions_schema_value = "${var.prefix}.public.transactions-value"
    prefix = var.prefix
  }

  # Capture dynamic values at creation time and write to a file for destroy-time use
  provisioner "local-exec" {
    when    = create
    command = <<-EOT
      # Store values needed for destroy-time cleanup in a temporary file
      mkdir -p .terraform/tmp
      cat > .terraform/tmp/schema-cleanup-values.json <<EOF
{
  "schema_registry_endpoint": "${data.confluent_schema_registry_cluster.card_tx_sr.rest_endpoint}",
  "schema_registry_key_id": "${confluent_api_key.app_manager_sr_key.id}",
  "prefix": "${var.prefix}"
}
EOF
      echo "Schema cleanup values stored for destroy-time cleanup"
    EOT
  }

  # Delete schemas when connector is destroyed
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      set -e
      
      # Try to read values from stored file, fallback to environment variables or triggers
      SR_ENDPOINT=""
      SR_KEY_ID=""
      PREFIX="${self.triggers.prefix}"
      
      # Read from stored JSON file if available (requires jq or use grep/sed fallback)
      if [ -f .terraform/tmp/schema-cleanup-values.json ]; then
        if command -v jq &> /dev/null; then
          SR_ENDPOINT=$(jq -r '.schema_registry_endpoint // empty' .terraform/tmp/schema-cleanup-values.json 2>/dev/null || echo "")
          SR_KEY_ID=$(jq -r '.schema_registry_key_id // empty' .terraform/tmp/schema-cleanup-values.json 2>/dev/null || echo "")
          PREFIX_STORED=$(jq -r '.prefix // empty' .terraform/tmp/schema-cleanup-values.json 2>/dev/null || echo "")
        else
          # Fallback: use grep/sed if jq not available
          SR_ENDPOINT=$(grep -o '"schema_registry_endpoint"[[:space:]]*:[[:space:]]*"[^"]*"' .terraform/tmp/schema-cleanup-values.json 2>/dev/null | sed 's/.*"\([^"]*\)".*/\1/' || echo "")
          SR_KEY_ID=$(grep -o '"schema_registry_key_id"[[:space:]]*:[[:space:]]*"[^"]*"' .terraform/tmp/schema-cleanup-values.json 2>/dev/null | sed 's/.*"\([^"]*\)".*/\1/' || echo "")
          PREFIX_STORED=$(grep -o '"prefix"[[:space:]]*:[[:space:]]*"[^"]*"' .terraform/tmp/schema-cleanup-values.json 2>/dev/null | sed 's/.*"\([^"]*\)".*/\1/' || echo "")
        fi
        if [ -n "$PREFIX_STORED" ]; then
          PREFIX="$PREFIX_STORED"
        fi
      fi
      
      # Fallback to environment variables if file values not available
      if [ -z "$SR_ENDPOINT" ] && [ -n "$SCHEMA_REGISTRY_ENDPOINT" ]; then
        SR_ENDPOINT="$SCHEMA_REGISTRY_ENDPOINT"
      fi
      if [ -z "$SR_KEY_ID" ] && [ -n "$SCHEMA_REGISTRY_KEY_ID" ]; then
        SR_KEY_ID="$SCHEMA_REGISTRY_KEY_ID"
      fi
      
      # Validate we have required values
      if [ -z "$SR_ENDPOINT" ] || [ -z "$SR_KEY_ID" ]; then
        echo "WARNING: Missing Schema Registry endpoint or key ID."
        echo "Set SCHEMA_REGISTRY_ENDPOINT and SCHEMA_REGISTRY_KEY_ID environment variables,"
        echo "or ensure .terraform/tmp/schema-cleanup-values.json exists from creation."
        echo "Skipping schema cleanup."
        exit 0
      fi
      
      # Try to get Schema Registry API secret from multiple sources
      SR_SECRET=""
      
      # Method 1: Environment variable (recommended for destroy operations)
      if [ -n "$SCHEMA_REGISTRY_API_SECRET" ]; then
        SR_SECRET="$SCHEMA_REGISTRY_API_SECRET"
        echo "Using Schema Registry API secret from SCHEMA_REGISTRY_API_SECRET environment variable"
      # Method 2: Try to get from Terraform output (if state still available)
      elif command -v terraform &> /dev/null; then
        TERRAFORM_OUTPUT=$(terraform output -raw schema_registry_api_secret 2>/dev/null || echo "")
        if [ -n "$TERRAFORM_OUTPUT" ]; then
          SR_SECRET="$TERRAFORM_OUTPUT"
          echo "Using Schema Registry API secret from Terraform output"
        fi
      fi
      
      if [ -z "$SR_SECRET" ]; then
        echo "WARNING: Could not obtain Schema Registry API secret."
        echo "Skipping schema cleanup. To enable cleanup, set:"
        echo "  export SCHEMA_REGISTRY_API_SECRET=\"<secret>\""
        echo ""
        echo "Schemas that may need manual deletion:"
        echo "  - ${self.triggers.customers_schema_key}"
        echo "  - ${self.triggers.customers_schema_value}"
        echo "  - ${self.triggers.transactions_schema_key}"
        echo "  - ${self.triggers.transactions_schema_value}"
        exit 0
      fi
      
      # Function to delete a schema subject
      delete_schema() {
        local subject=$1
        echo "Deleting schema subject: $subject"
        
        # Check if subject exists and get versions
        VERSIONS=$(curl -s -u "$SR_KEY_ID:$SR_SECRET" \
          "$SR_ENDPOINT/subjects/$subject/versions" \
          -H "Content-Type: application/vnd.schemaregistry.v1+json" 2>/dev/null || echo "[]")
        
        if [ "$VERSIONS" != "[]" ] && [ -n "$VERSIONS" ] && [ "$VERSIONS" != "Subject not found" ]; then
          # Delete all versions (hard delete with permanent=true)
          # Use %% to escape % in Terraform heredoc
          HTTP_CODE=$(curl -s -w "\n%%{http_code}" -u "$SR_KEY_ID:$SR_SECRET" \
            -X DELETE \
            "$SR_ENDPOINT/subjects/$subject?permanent=true" \
            -H "Content-Type: application/vnd.schemaregistry.v1+json" 2>/dev/null | tail -n1 || echo "000")
          
          if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "404" ]; then
            echo "Successfully deleted schema subject: $subject"
          else
            echo "Warning: Failed to delete schema subject $subject (HTTP $HTTP_CODE)"
          fi
        else
          echo "Schema subject $subject not found or already deleted"
        fi
      }
      
      # Delete all CDC schemas using stored trigger values
      delete_schema "${self.triggers.customers_schema_key}"
      delete_schema "${self.triggers.customers_schema_value}"
      delete_schema "${self.triggers.transactions_schema_key}"
      delete_schema "${self.triggers.transactions_schema_value}"
      
      echo "Schema cleanup completed"
    EOT
  }

  # Note: depends_on is not needed for destroy-time provisioners
  # The triggers capture the values at creation time
}

# -----------------------------------------------------------------------------
# S3 Sink Connector (for Iceberg/Parquet output)
# -----------------------------------------------------------------------------
resource "confluent_connector" "card_tx_s3_sink" {
  environment {
    id = confluent_environment.card_tx_env.id
  }

  kafka_cluster {
    id = confluent_kafka_cluster.card_tx_cluster.id
  }

  config_sensitive = {
    "aws.access.key.id"     = aws_iam_access_key.s3_sink_access_key.id
    "aws.secret.access.key" = aws_iam_access_key.s3_sink_access_key.secret
  }

  config_nonsensitive = {
    # Connector identification
    "connector.class" = "S3_SINK"
    "name"            = "${var.prefix}-s3-sink"

    # Authentication
    "kafka.auth.mode"          = "SERVICE_ACCOUNT"
    "kafka.service.account.id" = confluent_service_account.connectors.id

    # Topics to sink
    "topics" = "${var.prefix}-enriched-transactions,${var.prefix}-tx-aggregations"

    # S3 configuration
    "s3.bucket.name" = aws_s3_bucket.card_tx_iceberg.bucket
    "s3.region"      = var.cloud_region

    # Output format - Parquet for Iceberg compatibility
    "output.data.format" = "PARQUET"
    "input.data.format"  = "AVRO"

    # Partitioning
    "time.interval"       = "HOURLY"
    "path.format"         = "'year'=YYYY/'month'=MM/'day'=dd/'hour'=HH"
    "rotate.schedule.interval.ms" = "3600000"  # 1 hour

    # Performance
    "tasks.max"   = "1"
    "flush.size"  = "1000"
  }

  depends_on = [
    confluent_kafka_topic.card_tx_enriched,
    confluent_kafka_topic.card_tx_aggregations,
    confluent_kafka_acl.connectors_read_topic,
    aws_s3_bucket.card_tx_iceberg
  ]

  lifecycle {
    prevent_destroy = false
  }
}

# -----------------------------------------------------------------------------
# IAM User and Access Key for S3 Sink Connector
# -----------------------------------------------------------------------------
resource "aws_iam_user" "s3_sink_user" {
  name = "${var.prefix}-s3-sink-user-${random_id.env_display_id.hex}"

  tags = {
    Name = "${var.prefix}-s3-sink-user"
  }
}

resource "aws_iam_access_key" "s3_sink_access_key" {
  user = aws_iam_user.s3_sink_user.name
}

resource "aws_iam_user_policy" "s3_sink_policy" {
  name = "${var.prefix}-s3-sink-policy"
  user = aws_iam_user.s3_sink_user.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          aws_s3_bucket.card_tx_iceberg.arn,
          "${aws_s3_bucket.card_tx_iceberg.arn}/*"
        ]
      }
    ]
  })
}
