# A Java Table API demonstration

This demonstration illustrates multiple features using SQL client, Java application using Flink Table API, based on an imaginary airline use case to correlate different events on a flight.

* Run sql-client as pod in minikube to send mock data 
* Use FlinkFaker to send different data


## Start SQL client in minikube

* Build the custom flink image with the needed jars for connecting to Kafka, use FlinkFaker... using the Dockerfile in custom-flink-image

    ```sh
    minikube image build
    ```

* Deploy using the sql-client-deployment.yaml

    ```sh
    kubectl apply -f sql-client-deployment.yaml
    ```


## Create kafka topics to keep different events

```sh
```