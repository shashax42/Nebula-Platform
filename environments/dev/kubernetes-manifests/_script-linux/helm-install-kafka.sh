#!/bin/bash

helm repo add strimzi https://strimzi.io/charts/
helm repo update
helm install kafka strimzi/strimzi-kafka-operator --namespace backend