# A Set of example to use Table API and SQL

## Build

`mvn package`

## Run

Most of the main runs in IDE, if not start Flink task and job managers

```sh
docker compose up -d
```

```sh
CNAME=org.acme.FirstSQLApp
JMC=$(docker ps --filter name=jobmanager --format={{.ID}})  
docker exec -ti $JMC flink run -d -c $CNAME /home/target/flink-sql-quarkus-1.0.0.jar
```


