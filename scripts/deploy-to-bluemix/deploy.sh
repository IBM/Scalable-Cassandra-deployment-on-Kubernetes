#!/bin/bash

echo "Create Cassandra"
IP_ADDR=$(bx cs workers $CLUSTER_NAME | grep deployed | awk '{ print $2 }')
if [ -z $IP_ADDR ]; then
  echo "$CLUSTER_NAME not created or workers not ready"
  exit 1
fi

echo -e "Configuring vars"
exp=$(bx cs cluster-config $CLUSTER_NAME | grep export)
if [ $? -ne 0 ]; then
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
if [ ${#kuber} -ne 0 ]; then
	sleep 120s
fi

echo -e "Creating headless service"
kubectl create -f cassandra-service.yaml

echo -e "Creating Replication Controller"
kubectl create -f cassandra-controller.yaml

sleep 15s
STATUS=$(kubectl exec $(kubectl get pods | grep cassandra | awk '{print $1}') -- nodetool status | grep UN)

while [ ${#STATUS} -eq 0 ]
do
    echo "Waiting for Cassandra to finish setting up..."
    sleep 15s
    STATUS=$(kubectl exec $(kubectl get pods | grep cassandra | awk '{print $1}') -- nodetool status | grep UN)
done

kubectl exec $(kubectl get pods | grep cassandra | awk '{print $1}') -- nodetool status
kubectl scale rc cassandra --replicas=4

sleep 30s

TEST=$(kubectl exec $(kubectl get pods | grep cassandra | awk '{print $1}' | head -1) -- nodetool status | grep UN | awk '{print $1}')

while [ "${#TEST}" != "UN UN UN UN" ]
do
    kubectl exec $(kubectl get pods | grep cassandra | awk '{print $1}' | head -1) -- nodetool status
    echo ${#TEST}
    sleep 15s
    TEST=$(kubectl exec $(kubectl get pods | grep cassandra | awk '{print $1}' | head -1) -- nodetool status | grep UN | awk '{print $1}')
done

echo "Your cassandra cluster is now up and normal"
echo $(kubectl exec $(kubectl get pods | grep cassandra | awk '{print $1}' | head -1) -- nodetool status)


echo "You can also view your Cassandra cluster on your machine"
echo "Export your cluster configuration on your terminal:"
echo "$(bx cs cluster-config <your-cluster-name> | grep export)"
echo "Check the status of your Cassandra nodes"
echo "kubecl exec cassandra-0 -- nodetool status"
