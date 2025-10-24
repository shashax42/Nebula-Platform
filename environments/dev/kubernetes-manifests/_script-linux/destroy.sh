#!/bin/bash

cd ..

kubectl delete -f core-gateway
kubectl delete -f service-account
kubectl delete -f service-order
kubectl delete -f service-product
kubectl delete -f batch-order
kubectl delete -f data-kafka

helm uninstall kafka -n backend

kubectl delete -f role