# Json transformation – Confluent Cloud

## Goal

Run the truck rental JSON transformation (raw-orders + raw-jobs → nested OrderDetails) on Confluent Cloud for Flink. Validate the same business logic as the CP/Table API variant with minimal platform setup.

## Status

Ready. Requires Confluent Cloud with Kafka and Flink compute pool (or Flink workspace). Producer for test data: use [../src/producer/](../src/producer/) or Confluent UI.

## Implementation approach

- **No IaC in this folder:** Provision Kafka and Flink compute pool via Confluent Cloud UI or your own Terraform.
- **Application logic:** Flink SQL only. DDL and DML in this folder (`ddl.*.sql`, `dml.*.sql`). Deploy via Flink workspace UI or Confluent CLI.
- **Shared:** Schemas and producer live at demo root ([../src/schemas/](../src/schemas/), [../src/producer/](../src/producer/)).

## How to run

### Prerequisites

Confluent Cloud: Kafka cluster, Flink compute pool or workspace. Optionally [../src/producer/](../src/producer/) for generating test data.

### Steps to demonstrate the Json transformation logic

### Preparation

1. Create the raw input tables:
    * ddl.raw_orders.sql
    * ddl.raw_jobs.sql

1. Create the target sink table:
    * ddl.order_details.sql

1. Insert records to orders
    * dml.insert_raw_jobs.sql
    * dml.insert_raw_orders.sql
1. Verify records are visibles:
    ```sql
    select * from raw_orders
    select * from raw_jobs
    ```

### Build the Transformation logic. 

The OrderDetails is a json with EquipmentRentalDetails, an array of EquipmentRentalDetail, an orderid and the MovingHelpDetails.
1. The first goal is to build EquipmentRentalDetail and no MovingHelpDetails, see the [dml.extract_equipment_details.sql](./dml.extract_equipment_rental_details.sql)

1. Verify join will return results:
    ```sql
    select * from raw_jobs j left join raw_orders o on j.order_id = o.OrderId
    ```

1. Combine the two, by using CTEs:
    ```sql
    SELECT
        o.OrderId,
        ARRAY[
            row(
            o.OrderId,
            o.Status,
            o.Equipment,
            o.TotalPaid,
            o.`Type`,
            o.Coverage,
            o.Itinerary,
            o.OrderType,
            CAST(o.AssociatedContractId as BIGINT)
            )
        ] as EquipmentRentalDetails,
        ARRAY[ 
            ROW(
                j.job_id, 
                j.job_type,
                j.job_status,
                j.rate_service_provider,
                j.total_paid,
                j.job_date_start,
            j.job_completed_date,
            j.job_entered_date,
            j.job_last_modified_date,
            j.service_provider_name)
            ] as MovingHelpDetails
        from `raw-orders` o join raw_jobs j on j.order_id = o.OrderId
    ```

1. Group by and collect the jobdetail in an array: see the [dml.insert.order_details.sql](./dml.insert.order_details.sql)


### Validate the results
In the table view with: `select * from order_details` or with a json format:
    ```sql
    select OrderId, json_array(`EquipmentRentalDetails`), `MovingHelpDetails` from order_details
    ```

![](./docs/order_details.png)

![](./docs/moving_details.png)



### Cleanup
    ```sql
    drop table order_details
    drop table raw_jobs
    drop table raw_orders
    ```