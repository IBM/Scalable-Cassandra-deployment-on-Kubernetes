#!/bin/bash
kubectl create -f cassandra-service.yaml
kubectl create -f cassandra-controller.yaml
kubectl get nodes
kubectl get svc cassandra
