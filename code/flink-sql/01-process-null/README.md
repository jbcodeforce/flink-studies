# Propagating null column

By default when the schema defines nullable columns flink propagates those columns to the sink. This folder includes Confluent Cloud demonstrations to validate:

1. Create records with SQL insert into, with a column (testresults) set to NULL. Validate a transformation passes the null to the sink table

## Using Flink

1. Create a raw_tickets json schema, topic, table using Flink, add NULL value and see propagation into a sink
* Run under cc-flink:
    ```sh
    make deploy
    ```

![](https://github.com/jbcodeforce/flink-studies/edit/master/docs/coding/images/null_propagated.png)

## Kafka Producer

Use a Kafka Producer, for JSON payload and schema registry to register JSON schema. the code is [python/produce_raw_events.py](./python/produce_raw_events.py). 

It builds a RawTicket cycling through three testresults states.

    Cycle (1-based index mod 3):
      1 → testresults populated
      2 → testresults explicitly None  (null in JSON)
      0 → testresults omitted entirely (field not present in JSON)

The schema is:
```python
class RawTicket(BaseModel):
    case_id: str
    description: str
    priority: int
    owner: str
    testresults: str | None = None
    creation_ts: AwareDatetime

```

Which in JSON in the schema registry looks like:

```json
{
  "additionalProperties": false,
  "properties": {
    "case_id": {
      "title": "Case Id",
      "type": "string"
    },
    "creation_ts": {
      "format": "date-time",
      "title": "Creation Ts",
      "type": "string"
    },
    "description": {
      "title": "Description",
      "type": "string"
    },
    "owner": {
      "title": "Owner",
      "type": "string"
    },
    "priority": {
      "title": "Priority",
      "type": "integer"
    },
    "testresults": {
      "anyOf": [
        {
          "type": "string"
        },
        {
          "type": "null"
        }
      ],
      "default": null,
      "title": "Testresults"
    }
  },
  "required": [
    "case_id",
    "description",
    "priority",
    "owner",
    "creation_ts"
  ],
  "title": "RawTicket",
  "type": "object"
}
```

* Run the producer with:

```sh
uv run produce_raw_events.py
```

* Verify messages in the topic may have some testresults populated, not present or with Null values

```json
{
  "case_id": "case_9",
  "description": "description_9",
  "priority": 2,
  "owner": "owner_9",
  "creation_ts": "2026-09-15T04:49:42.073956Z"
}
```

```json
{
  "case_id": "case_8",
  "description": "description_8",
  "priority": 2,
  "owner": "owner_8",
  "testresults": null,
  "creation_ts": "2026-09-15T04:49:41.994816Z"
}
```

```json
{
  "case_id": "case_7",
  "description": "description_7",
  "priority": 2,
  "owner": "owner_7",
  "testresults": "result_7",
  "creation_ts": "2026-09-15T04:49:41.927574Z"
}
```

* Run a query like: `select * from raw_tickets`
    ![](https://github.com/jbcodeforce/flink-studies/edit/master/docs/coding/images/null_propagated_2.png)