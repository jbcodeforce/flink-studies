# Kafka Flink Demo project

A simple quarkus app with Flink data flow to process telemetries event from Kafka. See the [ReeferTelemetry simulator project](https://github.com/ibm-cloud-architecture/vaccine-reefer-simulator)

## Code approach

* Added Telemetry, TelemetryEvents and Telemetry Deserialization to reflect what the Reefer Simulator is sending to Kafka
* Add dependencies for Flink in maven: flink-java, flink-streaming-java_2.12, flink-connector-kafka_2.12, flink-clients_2.12
* Add dependencies for quarkus-kafka-client for json serialization
* Set `quarkus.package.type=uber-jar` in `application.properties`

## Running the application in dev mode

Start the Kafka, zookeeper, simulator, and Flink job manager locally with `docker-compose up -d` command. 

Then deploy the app as a job:

```shell
CNAME=jbcodeforce.kafka.TelemetryFlinkMain
JMC=$(docker ps --filter name=jobmanager --format={{.ID}})
docker exec -ti $JMC flink run -d -c $CNAME /home/target/kafka-flink-demo-1.0.0-runner.jar
```

Use curl to send some records from the Reefer simulator to kafka:

```shell
curl -X POST "http://localhost:5000/control" -H "accept: application/json" -H "Content-Type: application-json" -d "{ \"containerID\": \"C02\", \"nb_of_records\": 20, \"product_id\": \"P01\", \"simulation\": \"tempgrowth\"}"
```

Go to the Flink Task manager UI: [http://localhost:8081/](http://localhost:8081/) and in the Running jobs, if needed use the `docker logs` on the Task manager container to see the flow trace (from print() function)

> **_NOTE:_**  Quarkus now ships with a Dev UI, which is available in dev mode only at http://localhost:8080/q/dev/.


## Deploy on OpenShift

* Create a project: `oc new -project jbsandbox`
* Deploy Strimzi Kafka: `oc apply -k kustomize/strimzi`
* Deploy Reefer Simulator: `oc apply -k kustomize/reefer-simulator/`
* Deploy the flink app using:

```sh
 ./flink run-application --target kubernetes-application -Dkubernetes.cluster-id=eda-ocp-app-cluster -Dkubernetes.container.image=quay.io/jbcodeforce/kafkaflinkdemo local:///opt/flink/usrlib/kafka-flink-demo-1.0.0-runner.jar
```