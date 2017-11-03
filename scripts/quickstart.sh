#!/bin/bash
kubectl create -f cassandra-service.yaml
kubectl create -f local-volumes.yaml
kubectl create -f cassandra-statefulset.yaml
kubectl get nodes
kubectl get svc cassandra
