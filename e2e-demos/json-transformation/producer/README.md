## Producers Kubernetes Deployment

This folder includes Kubernetes job manifests to start the producer API and Web App to produce records for `jobs` and `orders` to the `raw-orders` and `raw-jobs` topics.

To test in standalone mode, you may need to verify namespace and config map are created

```sh
```

if not do:
```
kubectl -f ../k8s/rental.yaml
kubectl -f ../k8s/kafka_client_cm.yaml
```

## WebApp

* Deploy the WebApp
  ```sh
  # Deploy the API
  make deploy_producer_api
  # Setup port forwarding  
  make port_forward_producer_api
  # Test the API
  make test_api_health
  ```


## Job based
It is also possible to run the python code as job.

* Deploy config map and orders as kubernetes job to create 10 orders
  ```sh
  make deploy_order_producer
  ```

* Deploy job producer for 10 jobs
  ```sh
  make deploy_job_producer
  ```
