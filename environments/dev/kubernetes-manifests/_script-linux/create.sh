#!/bin/bash

cd ..

kubectl apply -f namespace

.\_script-linux\helm-install-kafka.sh
kubectl apply -f data-kafka

kubectl apply -f role
kubectl apply -f core-gateway
kubectl apply -f service-account
kubectl apply -f service-order
kubectl apply -f service-product
kubectl apply -f batch-order