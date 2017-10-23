#!/bin/bash

echo "Creating Cassandra"

echo -e "Configuring vars"
exp=$(bx cs cluster-config "$CLUSTER_NAME" | grep export)
if ! bx cs cluster-config "$CLUSTER_NAME" | grep export ; then
  echo "Cluster $CLUSTER_NAME not created or not ready."
  exit 1
fi
eval "$exp"

echo -e "Deleting previous version of Cassandra if it exists"
kubectl delete --ignore-not-found=true -f cassandra-service.yaml
kubectl delete --ignore-not-found=true -f cassandra-controller.yaml
kubectl delete --ignore-not-found=true -f cassandra-statefulset.yaml
kubectl delete --ignore-not-found=true -f local-volumes.yaml

kuber=$(kubectl get pods -l app=cassandra)
while [ ${#kuber} -ne 0 ]
do
	sleep 5s
    kubectl get pods -l app=cassandra
    kuber=$(kubectl get pods -l app=cassandra)
done

echo -e "Creating headless service..."
kubectl create -f cassandra-service.yaml

echo -e "Creating Replication Controller..."
kubectl create -f cassandra-controller.yaml

SEED_NODE=$(kubectl get pods | grep cassandra | awk '{print $1}')
echo "Seed node is ${SEED_NODE}"
echo "Waiting for Cassansdra Pod to initialize..."
sleep 30s


STATUS=$(kubectl exec "$SEED_NODE" -- nodetool status | grep UN)

while [ ${#STATUS} -eq 0 ]
do
    echo "Waiting for Cassandra to finish setting up..."
    sleep 10s
    STATUS=$(kubectl exec "$SEED_NODE" -- nodetool status | grep UN)
done

echo "Cassandra Node is UP and NORMAL"
kubectl exec "$SEED_NODE" -- nodetool status

echo "Scaling the Replication Controller..."
kubectl scale rc cassandra --replicas=4

sleep 5s

TEST=$(kubectl exec "$SEED_NODE" -- nodetool status | grep UN | awk '{print $1}')

while [ "${#TEST}" != "11" ]
do
    kubectl exec "$SEED_NODE" -- nodetool status
    # echo ${#TEST}
    echo "Waiting for all Cassandra nodes to join and set up."

    sleep 5s
    TEST=$(kubectl exec "$SEED_NODE" -- nodetool status | grep UN | awk '{print $1}')
done

echo "Your cassandra cluster is now up and normal"
kubectl exec "$SEED_NODE" -- nodetool status


echo "You can also view your Cassandra cluster on your machine"
echo "Export your cluster configuration on your terminal:"
echo "bx cs cluster-config <your-cluster-name> then copy the export line."
echo "Check the status of your Cassandra nodes"
echo "kubectl exec <pod-name> -- nodetool status"
