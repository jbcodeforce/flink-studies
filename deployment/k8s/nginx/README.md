# Defining NGINX as ingress controller

NGINX Ingress Controller, which is the standard way to manage external access to services within Kubernetes. For any Ingress resources defined
in the Kubernetes cluster, the NGINX Ingress Controller configures an NGINX server (which it runs internally) to act as an HTTP/HTTPS load balancer and reverse proxy, routing external traffic to your services.

An **Ingress Resource** is a Kubernetes API object that defines rules for routing external HTTP/HTTPS traffic to services within the cluster. It specifies hostnames, paths, and backend services.

Colima with kubernetes has no external IP address so better to use nodePort
Orbstack exposes 

## Installation

* Run `make deploy` to get helm repository for nginx, and deploy it under the nginx namespace
* Verify deployment with:
    ```sh
    k get pods -n nginx
    k get svc -n nginx
    ```
* `make undeploy`

