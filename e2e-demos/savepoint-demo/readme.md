# Demonstrate savepointing with Flink for Kubernetes

## Goals

Demonstrate how to stop and restart a stateful processing application with savepoints to continue where the application was stopped. The approach is to get one producer app which creates new basic records (sequence_id, value=2) in a newly created topics. The Flink SQL computes the sum of the value. So after n records sent the sum should be sequence_id * 2.  

 
## Steps 

1. Start minikube with the Confluent Platform operator and the Flink operator (see the [readme and makefile](../../deployment/k8s/README.md))
1. Define a simple Kafka cluster and a schema registry (see the [readme and makefile](../../deployment/k8s/README.md))
1. Create the orders topic

    ```sh
    kubectl apply -f orders-topic.yaml
    ```

1. Do a port forwarding to schema registry  

    ```sh
    k port-forward schemaregistry-0 8081:8081
    ```

1. One for the Kafka broker external listener

    ```sh
    k port-forward kafka-0 9092:9092
    ```

1. Upload the schema definition to the schema registry  

    ```sh
    python event_definitions.py
    ```

1. Start the Python event generator

    ```sh
    python event_generator.py 1000
    ```

1. Start a Flink application using the SQL runner
