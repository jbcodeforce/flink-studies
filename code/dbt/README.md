# Based on the Udemy  AirBnb training

[See the dbt chapter for summary of the practice](https://jbcodeforce.github.io/flink-studies/coding/dbt/).

## Summary

Once the dbt is install with uv. The approach is to implement the pipeline and the first step is to process raw tables to build sources staging layer.

### Snowflake Airbnb Raw Tables

* Two schemas: dev and raw. [See data import sql](https://github.com/nordquant/complete-dbt-bootcamp-zero-to-hero/blob/main/_course_resources/course-resources.md). [S3 AirBnB listing](s3://dbt-datasets/listings.csv), [reviews.csv](s3://dbt-datasets/reviews.csv) and [hosts](s3://dbt-datasets/hosts.csv).
* Get connection to database like snowflake using the profiles.yml which should be under ~/.dbt or .gitgnore.
* Airbnb models:
    * Listings
    * Reviews
    * Hosts
