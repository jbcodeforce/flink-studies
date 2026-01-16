# Confluent Tableflow

This chapter is based to public knowledge, product documentation, and customer engagements experiences. 

The first level of information is the [product blog](https://www.confluent.io/blog/introducing-tableflow/), and the [main product page](https://www.confluent.io/product/tableflow/) as well as the [product documentation](https://docs.confluent.io/cloud/current/topics/tableflow/get-started/overview.html) for Confluent Cloud.

[This video deep dive into the technology](https://current.confluent.io/post-conference-videos-2025/tableflow-not-just-another-kafka-to-iceberg-connector-lnd25)

## Goals

TableFlow allows to represent a Kafka topic and associated schema as a table in [Apache Iceberg](https://iceberg.apache.org/) or Delta Lake format. It becomes the mediation layer between operational data and analytical data zone. It is using the schema registry to get the schema definition of the table.  It addresses a unified storage view on top of object storage.

Kafka topic is the source of truth of the data. Tableflow supports the [open table]() format: a table and catalog for analytics. It is part of the [data as a product](../methodology/data_as_a_product.md) architecture.

For Data engineers in data lakehouse environment, kafka topic is seen as table.

???- info "open table format"
    Open table formats are an open-source technology for storing tabular data that builds on top of existing file formats like Parquet or CSV files. It adresses the needs for query performance and reliability of data lake tables, by adding metadata on top of the tabular data. It was developed to bring ACID guarantees, on write operations.

### Pains

The classical high level view to move data from Kafka topics to lake house often rely on complex ETL pipelines, manual data wrangling, and custom governance processes. It is error prone work to map each one into an Iceberg table by hand.

![](./diagrams/tf_hl_current_flow.drawio.png)

* At the ingestion layer the type conversion, schematization, synchronize metadata to catalog, perform tables management
* The bronze landing zone will have raw tables with Iceberg Metadata.
* At the data preparation layer the ELT batch processing addresses deduplication, business metric creations, enforcing business rules and constraints.
* A lot of infrastructure to manage to consume the data out of Kafka, use custom program to transform to Iceberg and Parquet tables.

### Value Propositions

* It is a Cloud service, per region.
* The data from the topic is moved to object storage in **parquet format** with **Iceberg metadata**. 
* Need to bring your own object storage (s3 bucket) or use Confluent Cloud internal storage which is on top of Object Storage
* Work with private network, using gateway private endpoints to S3. No traffic over public internet.
* Data refreshness is down to 15mn, default 6 hours. For higher need, it can read from broker directly, at the minute level.
* Start from the earliest offset.
* Can compact multiple small files in bigger file.
* It keeps track of committed osffset in iceberg.
* Write data as encrypted at source level.
* Charge for sink connector and egress is waived, pricing is based on per topic/hour and GB processed.
* When using both Iceberg  and Delta metadata, the data will not be duplicated in the S3 bucket.
* This is a simple to setup by enabling Tableflow synching at the Kafka topic level.
* Support Upsers semantic

### Current limitations

* DLQ not supported yet
* Iceberg format is not supported in Databricks
* Catalog integration through private link, one catalog per cluster.
* Debezium CDC support

## Architecture

* Kafka cluster on Confluent Cloud
* Tableflow own catalog
* S3 access policy and service role
* The data is visible into the bucket after 15mn or 250MB filled.
* 300 MBs per kafka partition uncompressed payload
* Busy topic the quicker the data will be visible in the table
* Amazon Athena by using the AWS Glue Data Catalog

## Special Capabilities

* Upserts: update on the same key- Tombstone records are supported as Delete operation
* High performance unbound deduplication window
* Supports: 8+ B Unique rows per table
* DLQ: events that fails to materialize to the table are logged in a separate destination: this is relevant for zero tolerance for data loss. Each topic may have its own DLQ.
* Tableflow enables integrating with the AWS Glue Data Catalog as an external catalog, allowing the metadata of Apache Iceberg™ tables materialized by Tableflow to be published to AWS Glue. The AWS Glue Data Catalog integrates with Tableflow at the kafka cluster level, enabling the automatic publication of all Tableflow-enabled topics as tables within Glue
* Perform all write and maintenance operations through Tableflow, to ensure consistency and correctness.

## Iceberg Tables in S3

The integration process includes:

* Getting a S3 bucket
* Creating an IAM Role with policy to read, putobject,.. on S3 bucket. Or if using an existing IAM Role (e.g. `j9r-role` so the role can access S3:
    ```json
    {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListAllMyBuckets"
            ],
            "Resource": [
                "arn:aws:s3:::*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket",
                "s3:GetBucketLocation",
                "s3:ListBucketMultipartUploads"
            ],
            "Resource": [
                "arn:aws:s3:::j9r-demo-buckets"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:PutObjectTagging",
                "s3:GetObject",
                "s3:AbortMultipartUpload",
                "s3:ListMultipartUploadParts"
            ],
            "Resource": [
                "arn:aws:s3:::j9r-demo-buckets/*"
            ]
        }
        ]
    }
    ```

* Creating a Confluent Provider Integration to grant CC access to the AWS S3 bucket. It uses IAM Roles based authorization. The  provider integration to act-as a trusted identity. [See step by step instructions](https://docs.confluent.io/cloud/current/integrations/provider-integrations/create-provider-integration-aws.html#create-provider-integration-aws-steps). When asked to enter AWS role ARN, use your existing IAM role (e.g. `arn:aws:iam::8.....5:role/j9r-role`).
* Update the IAM role trust relationships by specifying the principal and externalId from Confluent provider integration IAM role to be able to assume the AWS role we configured (e.g. `j9r-role`).
    ```json
    {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::8......2:role/cspi-1y3y5"
            },
            "Action": "sts:AssumeRole",
            "Condition": {
                "StringEquals": {
                    "sts:ExternalId": "636d..........dd"
                }
            }
        },
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::8.....2:role/cspi-1y3y5"
            },
            "Action": "sts:TagSession"
        }
        ]
    }
    ```

* Enable Tableflow at the topic level
* Wait for the topic to be materialized as an Iceberg table in that bucket. This may take a few minutes depending on segment roll and throughput.
*  Integrate Tableflow with AWS Glue Data Catalog: Tableflow > External Catalog Integrations > AWS Glue:
    * Provide an IAM role for Confluent to assume, with the required Glue permissions (Create/Get/Update/Delete Database/Table, etc.)
        ```json
        # statement to add to the list of statements
        {
            "Effect": "Allow",
            "Action": [
                "glue:GetTable",
                "glue:GetDatabase",
                "glue:DeleteTable",
                "glue:DeleteDatabase",
                "glue:CreateTable",
                "glue:CreateDatabase",
                "glue:UpdateTable",
                "glue:UpdateDatabase"
            ],
            "Resource": [
                "arn:aws:glue:us-west-2:829250931565:*"
            ]
        }
        ```
    * Launch the integration. Tableflow then publishes Iceberg table metadata to AWS Glue for all materialized tables in that Kafka cluster. Here is a view of the created tables from the transaction processing:
    ![](./images/glue-tableflo-tables-.png)

## External query

* Need to define a catalog like AWS Glue, Databricks Unity Catalog: The Cluster Id will become the database in Glue.

### Query with AWS Athena

* Configure AWS Glue Catalog integration in Tableflow (see above)
* Ensure you have the required permissions for Amazon Athena to access the table’s storage bucket. This translates as: attach an IAM policy granting s3:GetObject, s3:ListBucket, s3:GetBucketLocation, etc., to the IAM Role Athena uses (often the Glue Service Role), ensure the S3 Bucket Policy allows access from that role/account, and check AWS KMS permissions if encryption is used.
* Ensure AWS Athena has read-only access to the Glue catalog and the storage bucket.

### Query TableFlow tables with Duckdb

* Install the DuckDB command-line tool.
    ```sh
    curl https://install.duckdb.org | sh
    or
    uv add duckdb-cli
    ```
* Create a new Tableflow API Key for the cluster where Tableflow is enabled, use the key name as a the duckdb CLIENT_ID and the api key secret as CLIENT_KEY
* Retrieve the connection detail (REST Catalog Endpoint) for the TableFlow API, something like `https://tableflow.<<REGION>>.aws.confluent.cloud/iceberg/catalog/organizations/YOUR-ORG-ID/environments/YOUR-ENV-ID`
* Match the database to the Kafka cluster_id and the topic name being the table name
* In the duckdb shell, add the iceberg extension. The installation is done only one time.
    ```
    INSTALL iceberg;
    LOAD iceberg;
    ```

* Add a secret definition:
    ```sql
    CREATE SECRET iceberg_secret (
        TYPE ICEBERG,
        CLIENT_ID     'YOUR_CLIENT_ID',
        CLIENT_SECRET 'YOUR_CLIENT_SECRET',
        ENDPOINT      'YOUR_ENDPOINT_URL',
        OAUTH2_SCOPE  'catalog'
    )
    ```
* Attach the tableflow catalog by using an alias: `ice_cat` 
    ```sql
    ATTACH 'warehouse' AS ice_cat (
        TYPE iceberg,
        SECRET iceberg_secret,
        ENDPOINT 'YOUR_ENDPOINT_URL'
        );
    ```

* Run SQL queries on top of the tableflow tables:
    ```sql
    SELECT * FROM ice_cat."lkc-3mnm0m"."customer_analytics_c360";
    -- add joins, filters,..
    ```

* In case of session timeout, restart DuckDB and rerun recreate the secret and attach the catalog again.
* See also a Python application using duckdb integration in [this app]()
