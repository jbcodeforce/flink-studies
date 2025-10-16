# Health Care Example of Json Transformation

This folder includes a set of Flink SQL to run on Confluent Cloud, to demonstrate processing of CDC records for transformation from nested CDC Json schema to flatten JSON schema for business entities construction. The basic use case is for insurance member and medical provider.


## Source Data Structure

We'll need to handle CDC data from two main sources:

- Person MDM data (for Member entity)
- Medical Provider master data (for Provider entity)

The existing architecture includes ETL jobs in Qlik to Kafka topics for CDC records: source database tables include different part of the information to group to the different final json business entities: Member and Provider.

## Business Entities

The demonstration may add more business entities, if needed, with the potential candidates are:

* Member
* Group
* Claims
* Pharmacy Claim
* Provider

Thoses entities may be saved to a document oriented database like MongoDB or Cassandra.

### 1. Define Target Entity Schemas

Create JSON schemas for Member and Provider entities with basic fields:

Member Entity:

```json
{
  "member_id": "string",
  "first_name": "string",
  "last_name": "string",
  "date_of_birth": "string",
  "address": {
    "street": "string",
    "city": "string",
    "state": "string",
    "zip": "string"
  },
  "phone": "string",
  "email": "string"
}
```

Provider Entity:

```json
{
  "provider_id": "string",
  "first_name": "string",
  "last_name": "string",
  "specialty": "string",
  "primary_location": {
    "facility_name": "string",
    "address": {
      "street": "string",
      "city": "string",
      "state": "string",
      "zip": "string"
    }
  },
  "contact_number": "string",
  "npi_number": "string"
}
```

### 2. Flink SQL Implementation

As we do not want to put in place a CDC with QLIK or Debezium we need to mock the raw data. The `sql/mock_qlik_output` folder includes the DDL and insert statements to create sample records:

1. `cc-flink-health/sql/mock_qlik_output/ddl.person_mdm.sql` and `cc-flink-health/sql/cmock_qlik_output/ddl.provider_master.sql`:

   - Create source tables for Person MDM and Provider master data
   - Use json-registry encoding
   - changelog mode is append as it should be with any CDC output
   - Include metadata columns for CDC operations

2. `cc-flink-health/sql/cmock_qlik_output/insert_provider_masters.sql`
   - insert 2 Provider records to validate deduplication and filtering.

2. `cc-flink-health/sql/cmock_qlik_output/ddl.provider_dimension.sql` and `cc-flink-health/sql/cmock_qlik_output/ddl.menber_dimension.sql`:

   - Create sink tables for Member and Provider entities
   - Use upsert change log to keep the last event per key with json encoding

3. `cc-flink-health/sql/member_transform.sql`:

   - Transform Person MDM data into Member entity
   - Handle CDC operations (INSERT, UPDATE, DELETE)
   - Apply field mappings and transformations

4. `cc-flink-health/sql/provider_transform.sql`:

   - Transform Provider master data into Provider entity
   - Handle CDC operations
   - Apply field mappings and transformations


## File Structure

```
cc-flink-health/
├── README.md (updated)
├── schemas/
│   ├── member.json
│   └── provider.json
├── sql/
│   ├── ddl.member_dimension.sql
│   ├── ddl.provider_dimension.sql
│   ├── ddl.provider_error_sink.sql
│   ├── member_transform.sql
│   ├── mock_qlik_output
│   │   ├── cmp.txt
│   │   ├── ddl.person_mdm.sql
│   │   ├── ddl.provider_master.sql
│   │   ├── insert_person_mdm.sql
│   │   ├── insert_provider_master.sql
│   │   └── insert_provider_masters.sql
│   └── provider_transform.sql
└── test/
    ├── input/
    │   ├── person_cdc.json
    │   └── provider_cdc.json
    └── expected/
        ├── member.json
        └── provider.json
```

## Deploy to Confluent Cloud

Follow the following steps to demonstrate the transformation processing:

### Prerequisites

* As a pre-requisite be sure to have define the SEQUENCE User Define Function deployed in you Environment (see [this repository](https://github.com/jbcodeforce/flink-udfs-catalog/tree/main/geo_distance))
* Create a compute pool and open the SQL Workspace

### Create mockup CDC topics using SQL Workbench

1. Copy/paste the content of `sql/mock_qlik_output/ddl.person_mdm.sql` and run
1. Copy/paste the content of `sql/mock_qlik_output/ddl.provider_master.sql` and run
1. Verify the topics are created and JSON schemas are in the Schema Registry
1. Insert data using the SQL: `sql/cmock_qlik_output/insert_provider_masters.sql` wait until completed. Then validate the presence of the 3 records:
    ```sql
    select * from provider_master
    ```
    Then stop the statement.
1. Insert member records using a Kafka Producer code:
    ```
    cd producer
    uv run member_mdm_producer.py --num-records 10
    ```
1. Verify in Flink the presence of the records using `select * from `person_mdm`

### Transformation for the person / members

This will be a simple json to json transformation using the record as string in the data column to a valid member_dimension. This is to illustrate JSON extraction from String and then creation of new nested json objects. Below is some constructs used

* Extract attribute from the data string:
  ```sql
   JSON_VALUE(data, '$.member_id') AS member_id,
  ```

* Extrating nested object to recreate a new nexted object
  ```sql
    ROW(
        JSON_VALUE(JSON_QUERY(data,'$.address'), '$.street'),
        JSON_VALUE(JSON_QUERY(data,'$.address'), '$.city'),
        JSON_VALUE(JSON_QUERY(data,'$.address'), '$.state'),
        JSON_VALUE(JSON_QUERY(data,'$.address'), '$.postal_code')
    ) AS address,
  ```

* Filtering out delete operation, looking at the headers
  ```sql
  FROM person_mdm WHERE headers.op <> 'DELETE';
  ```

### Transformation for Provider

The input structure has nested elements to transform from, by using the same patterns as above. There are array of json object in the source:

* Source to process has array of object with other nested array
  ```json
  {
    "changeSet": [
      {
        "name": "NetworkSet",
        "changes": [
          {
            "action": "A1",
            "recordKeys": {
              "providerNetworkId": "1234"
            },
            "srcPublishRef": "srcPubRef01"
          }
        ]
      }
    ]
  }
```

* If we want to extract the action and the providerNetworkId to flatten the model the query looks like
  ```sql
  cast(changeSet[1].changes[1].action as string) as action 
  ```


