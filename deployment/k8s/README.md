# Install Flink on k8s with the operator

## Pre-requisites

* Be sure to have helm installed: `brew install helm`
* Install certification manager once per k8s cluster: `kubectl create -f https://github.com/jetstack/cert-manager/releases/download/v1.8.2/cert-manager.yaml`
* Get the [list of Flink releases and tags here](https://downloads.apache.org/flink/)
* Add Helm repo: `helm repo add flink-operator-repo https://downloads.apache.org/flink/flink-kubernetes-operator-1.9.0`
* Install the open-source operator: 

```sh
helm install flink-kubernetes-operator flink-operator-repo/flink-kubernetes-operator
```

## Deploy the different applications

### Top-speed demo

The processing 

