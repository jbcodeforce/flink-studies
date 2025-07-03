#!/bin/bash

NGINX_VERSION=4.10.6
NGINX_NAMESPACE=nginx

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx --force-update
helm repo update

kubectl create namespace ${NGINX_NAMESPACE}

helm upgrade --install ingress-nginx \
    ingress-nginx/ingress-nginx \
    --namespace ${NGINX_NAMESPACE} \
    --set "controller.extraArgs.enable-ssl-passthrough=" \
    --version ${NGINX_VERSION}