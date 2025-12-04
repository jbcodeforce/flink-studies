# Flink SQL Client

???+ Info "Updates"
    Created 12/25

SQL Client helps developers to write and submit table programs to a Flink cluster without a single line of Java code. From this client, it is possible to get the results of the query in real-time.

## Source of Information

* [Apache Flink SQL client](https://nightlies.apache.org/flink/flink-docs-master/docs/dev/table/sqlclient/)

## Getting started with a Apache Flink SQL client

* Lets start:
    ```sh
    # Under the Apache Flink folder. (e.g. deployment/product-tar), start the cluster
    ./bin/start_cluster.sh
    # Start the client in embedded mode, which means address local machine 
    ./bin/sql-client.sh
    ```
* [See product documentation on running SQL queries](https://nightlies.apache.org/flink/flink-docs-master/docs/dev/table/sqlclient/#running-sql-queries).
* Use the `-f` option to execute a SQL file in a Session Cluster
    ```sh
    # In this mode, the client will not open an interactive terminal.
    ./bin/sql-client.sh -f query_file.sql
    ```
* [Play with some first queries (code/flink-sql/00-basis-sql)](https://github.com/jbcodeforce/flink-studies/tree/master/code/flink-sql/00-basic-sql)

## Basic commands

* Show catalogs, tables... By default there is a default catalog, `default_catalog`, and database, `default_database`, without any table.

    ```sql
    SHOW CATALOGS;
    USE CATALOG `examples`;
    SHOW DATABASES;
    USE `marketplace`;
    SHOW TABLES;
    SHOW TABLES LIKE '*_raw'
    SHOW JOBS;
    DESCRIBE tablename;
    DESCRIBE EXTENDED table_name;
    ```


## Confluent Cloud SQL Client via CLI

Confluent Cloud enables users to write Flink SQL statements through the web console or a CLI shell.

[See quick start product documentation](https://docs.confluent.io/cloud/current/flink/get-started/quick-start-shell.html) which is summarized as:

* Connect to Confluent Cloud with CLI, then get the environment and compute pool identifiers. (change the name of your env)
    ```sh
    confluent login --save
    export ENV_NAME=j9r-env
    export ENV_ID=$(confluent environment list -o json | jq -r '.[] | select(.name == "'$ENV_NAME'") | .id')
    export COMPUTE_POOL_ID=$(confluent flink compute-pool list -o json | jq -r '.[0].id')
    echo $COMPUTE_POOL_ID
    ```

* Start local SQL client - using the `aws-west` environment.
    ```sh
    confluent flink shell --compute-pool $COMPUTE_POOL_ID --environment $ENV_ID
    ```
* Be sure to set catalog and database:
    ```sql
     use catalog `j9r-env`;
     use database `j9r-kafka`;
     ```

* Write SQL statements, get the results in the active session.

## Confluent Cloud Flink Workspace

There is already a lot of tutorials and videos on how to use the Workspace. Things to keep in mind:

* The Workspace is great to implement a SQL query step by step, CTE by CTE.
* A workspace is linked to a compute pool, add more compute pools.
* The query needs to be copy/paste into a file to be managed as software in git, for example.
* Run in a cell, a query 'inserting into', will run forever and it is easy, while developing queries, to forget about them.
* Use the left navigation tree to access list of tables, views, models, external datasources..

See also the Terraform to create Confluent Cloud resources in [this note](terraform.md).

All the SQL studies in [code/flink-sql folder](https://github.com/jbcodeforce/flink-studies/tree/master/code/flink-sql) include SQL queries for Confluent Cloud or CP Flink.

## Confluent Platform for Flink

When using Kubernetes deployment, it is recommended to package the SQL script with a Java program . This can be by using the Flink TableAPI, or use a Java program, called SQL Runner. The java jar is deployed as a Flink Application using a FlinkDeployment descriptor.

Use one of the following approaches:

* When using Flink with docker compose: the SQL client in the docker container runs against local Flink cluster (see [deployment/custom-flink-image](https://github.com/jbcodeforce/flink-studies/tree/master/deployment/custom-flink-image) folder to build a custom image using the dockerfile with the `sql-client` service and any specific connector jars). To interact with Flink using the SQL client, open a bash in the running container, or in the flink bin folder:
    ```sh
    # be sure to mount the folder with sql scripts into the container

    # Using running job manager running within docker
    docker exec -ti sql-client bash
    # in kubernetes pod
    kubectl exec -ti pod_name -n namespace -- bash
    # in the shell /opt/flink/bin 
    ./sql-client.sh
    ```


* Run SQL in Kubernetes application: 
    * Write SQL statements and test them with Java SQL runner. The Class is in [flink-studies/code/flink-java/sql-runner](https://github.com/jbcodeforce/flink-studies/tree/master/code/flink-java/sql-runner) folder. Then package the java app and sql script into a docker image then use a FlinkDeployment  descriptor; (see [this git doc](https://github.com/apache/flink-kubernetes-operator/tree/main/examples/flink-sql-runner-example)). 
    * As another solution write [Table API](./table-api.md) code that can also include SQL.





