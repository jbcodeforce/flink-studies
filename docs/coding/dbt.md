# Data Build Tool Summary

* [Dbt core](https://github.com/dbt-labs/dbt-core) is an open source CLI and database agnostic. It enables data teams to transform data within their warehouse using SQL by applying software engineering best practices like version control.
* [dbt Cloud](): A managed service with a web-based IDE, scheduler, job orchestration, and monitoring

## Use Cases

* Modelling changes are easy to follow and revert
* Explicit dependencies between models
* Explore dependencies between models
* Data quality tests
* Incremental load of fact tables
* Track history of dimension tables

## Install

* [Supported Python database](https://docs.getdbt.com/faqs/Core/install-python-compatibility)

## Snowflake example

* Two schemas: dev and raw. [See data import sql](https://github.com/nordquant/complete-dbt-bootcamp-zero-to-hero/blob/main/_course_resources/course-resources.md). [S3 AirBnB listing](s3://dbt-datasets/listings.csv), [reviews.csv](s3://dbt-datasets/reviews.csv) and [hosts](s3://dbt-datasets/hosts.csv).

## Sources

* [Udemy training from Zoltan C. Toth](https://www.udemy.com/course/complete-dbt-data-build-tool-bootcamp-zero-to-hero-learn-dbt) with [Git Repo](https://github.com/nordquant/complete-dbt-bootcamp-zero-to-hero). Example of data [from Inside AirBnB](https://insideairbnb.com/berlin/).
* [Dbt core](https://github.com/dbt-labs/dbt-core)
* [Preset]()
* [Snowflake](https://app.snowflake.com)  username: jbcodeforce. Using key-pair authentication. Public [key in Snowlflake](https://docs.snowflake.com/en/user-guide/opencatalog/key-pair-auth-configure#generate-a-private-and-public-key)