# AWS S3 Bucket for Confluent Cloud Sink Connector

This Terraform configuration creates an AWS S3 bucket with the necessary IAM user and permissions for Confluent Cloud S3 sink connector.

## Resources Created

- **S3 Bucket**: Storage for Kafka messages from Confluent Cloud
- **IAM User**: Service account for Confluent Cloud authentication
- **IAM Policy**: Permissions for S3 operations (ListBucket, GetObject, PutObject, DeleteObject)
- **Access Keys**: AWS credentials for the IAM user

## Prerequisites

1. AWS CLI configured with appropriate permissions
2. Terraform installed (>= 1.0)
3. AWS account with permissions to create S3 buckets and IAM resources

## Usage

1. **Initialize Terraform**:
   ```bash
   terraform init
   ```

2. **Copy and customize variables**:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your values
   ```

3. **Plan the deployment**:
   ```bash
   terraform plan
   ```

4. **Apply the configuration**:
   ```bash
   terraform apply
   ```

5. **Get the output values**:
   ```bash
   # Get all outputs
   terraform output
   
   # Get specific output (sensitive values)
   terraform output -raw secret_access_key
   terraform output confluent_s3_connector_config
   ```

## Configuration Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `aws_region` | AWS region for resources | `us-west-2` | No |
| `environment` | Environment name | `dev` | No |
| `project_name` | Project name for resource naming | `flink-studies` | No |
| `bucket_name` | S3 bucket name (must be globally unique) | Auto-generated | No |
| `force_destroy` | Allow deletion of non-empty S3 bucket | `false` | No |
| `versioning_enabled` | Enable S3 bucket versioning | `false` | No |
| `enable_encryption` | Enable S3 bucket server-side encryption | `true` | No |
| `enable_public_access_block` | Enable S3 bucket public access block | `true` | No |

## Outputs

- `s3_bucket_name`: Name of the created S3 bucket
- `s3_bucket_arn`: ARN of the S3 bucket
- `s3_bucket_region`: AWS region of the S3 bucket
- `iam_user_name`: Name of the IAM user
- `iam_user_arn`: ARN of the IAM user
- `access_key_id`: AWS Access Key ID
- `secret_access_key`: AWS Secret Access Key (sensitive)
- `confluent_s3_connector_config`: Complete configuration for Confluent Cloud S3 sink connector

## Confluent Cloud S3 Sink Connector Configuration

After applying this Terraform configuration, use the output values to configure your Confluent Cloud S3 sink connector:

```json
{
  "connector.class": "S3_SINK",
  "kafka.api.key": "YOUR_KAFKA_API_KEY",
  "kafka.api.secret": "YOUR_KAFKA_API_SECRET",
  "topics": "your-topic-name",
  "input.data.format": "JSON",
  "output.data.format": "JSON",
  "s3.bucket.name": "<OUTPUT: s3_bucket_name>",
  "s3.region": "<OUTPUT: s3_bucket_region>",
  "aws.access.key.id": "<OUTPUT: access_key_id>",
  "aws.secret.access.key": "<OUTPUT: secret_access_key>",
  "time.interval": "HOURLY",
  "flush.size": "1000",
  "tasks.max": "1"
}
```

## IAM Permissions

The created IAM policy includes the following permissions on the S3 bucket:

- **Bucket-level permissions**:
  - `s3:ListBucket`
  - `s3:GetBucketLocation`

- **Object-level permissions**:
  - `s3:GetObject`
  - `s3:PutObject`
  - `s3:DeleteObject`

## Security Considerations

1. **Access Keys**: The generated access keys are stored in Terraform state. Ensure your state file is encrypted and stored securely.

2. **Bucket Access**: The bucket is configured with public access blocked by default.

3. **Encryption**: Server-side encryption is enabled by default.

4. **Least Privilege**: The IAM policy follows the principle of least privilege, granting only the permissions necessary for the S3 sink connector.

## Cleanup

To destroy the resources:

```bash
terraform destroy
```

**Note**: If `force_destroy` is set to `false` and the bucket contains objects, you'll need to empty the bucket manually before destroying.

## Troubleshooting

### Common Issues

1. **Bucket name already exists**: S3 bucket names must be globally unique. If you get this error, either specify a custom `bucket_name` or let the auto-generation create a unique name.

2. **Permission errors**: Ensure your AWS credentials have the necessary permissions to create S3 buckets and IAM resources.

3. **State locking**: If using remote state, ensure proper state locking is configured to prevent concurrent modifications.

### Useful Commands

```bash
# Check bucket contents
aws s3 ls s3://YOUR_BUCKET_NAME

# Test access with created credentials
export AWS_ACCESS_KEY_ID="<access_key_id>"
export AWS_SECRET_ACCESS_KEY="<secret_access_key>"
aws s3 ls s3://YOUR_BUCKET_NAME
```
