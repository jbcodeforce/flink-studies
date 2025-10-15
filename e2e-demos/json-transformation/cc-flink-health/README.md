# Health Care Example of Json Transformation

## Source Data Structure

We'll need to handle CDC data from two main sources:

- Person MDM data (for Member entity)
- Medical Provider master data (for Provider entity)


The existing architecture includes ETL jobs in Qlik to Kafka topic for CDC records: source database tables include different part of the information to group to the different final json business entities

## Business Entities

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

Create the following Flink SQL files:

1. `cc-flink-health/sql/create_sources.sql`:

   - Create source tables for Person MDM and Provider master data
   - Use CDC format with debezium-json encoding
   - Include metadata columns for CDC operations

2. `cc-flink-health/sql/create_sinks.sql`:

   - Create sink tables for Member and Provider entities
   - Use upsert-kafka connector with json encoding
   - Configure key fields for proper updates

3. `cc-flink-health/sql/member_transform.sql`:

   - Transform Person MDM data into Member entity
   - Handle CDC operations (INSERT, UPDATE, DELETE)
   - Apply field mappings and transformations

4. `cc-flink-health/sql/provider_transform.sql`:

   - Transform Provider master data into Provider entity
   - Handle CDC operations
   - Apply field mappings and transformations

### 3. Confluent Cloud Configuration

Create configuration files for:

- Source topics (CDC data)
- Target topics (transformed entities)
- Flink compute pool settings
- Connector configurations

### 4. Testing and Validation

Create test data files:

- Sample CDC records for Person data
- Sample CDC records for Provider data
- Expected output records for validation

## File Structure

```
cc-flink-health/
├── README.md (updated)
├── schemas/
│   ├── member.json
│   └── provider.json
├── sql/
│   ├── create_sources.sql
│   ├── create_sinks.sql
│   ├── member_transform.sql
│   └── provider_transform.sql
├── config/
│   └── confluent-cloud.properties
└── test/
    ├── input/
    │   ├── person_cdc.json
    │   └── provider_cdc.json
    └── expected/
        ├── member.json
        └── provider.json
```

## Deploy to Confluent Cloud

### Create mockup CDC topics

* As a pre-requisite be sure to have define the SEQUENCE UDF (see [this repository]())