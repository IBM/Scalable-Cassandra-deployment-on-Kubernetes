#!/bin/bash -e

test_failed(){
    echo -e >&2 "\033[0;31mKubernetes test failed!\033[0m"
    exit 1
}

test_passed(){
    echo -e "\033[0;32mKubernetes test passed!\033[0m"
    exit 0
}

setup_dind-cluster() {
    wget https://cdn.rawgit.com/Mirantis/kubeadm-dind-cluster/master/fixed/dind-cluster-v1.7.sh
    chmod 0755 dind-cluster-v1.7.sh
    ./dind-cluster-v1.7.sh up
    export PATH="$HOME/.kubeadm-dind-cluster:$PATH"
}

kubectl_deploy() {
    echo -e "Creating headless service..."
    kubectl create -f cassandra-service.yaml

    echo -e "Creating Replication Controller..."
    kubectl create -f cassandra-controller.yaml

    while [[ $(kubectl get pods -l app=cassandra | grep -c Running) -ne 1 ]]; do
        if [[ ! "$i" -lt 24 ]]; then
            echo "Timeout waiting on pods to be ready. Test FAILED"
            exit 1
        fi
        sleep 10
        echo "...$i * 10 seconds elapsed..."
        ((i++))
    done

    echo "All pods are running"
}

verify_deploy(){
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

    echo "Cassandra Seed Node is UP and NORMAL"
    kubectl exec "$SEED_NODE" -- nodetool status

    echo "Scaling the Replication Controller..."
    kubectl scale rc cassandra --replicas=4
    sleep 5s

    SCALE=$(kubectl exec "$SEED_NODE" -- nodetool status | grep UN | awk '{print $1}')

    while [ "${#SCALE}" != "11" ]
    do
        kubectl exec "$SEED_NODE" -- nodetool status
        echo "Waiting for all Cassandra nodes to join and set up."
        sleep 5s
        SCALE=$(kubectl exec "$SEED_NODE" -- nodetool status | grep UN | awk '{print $1}')
    done

    echo "Your cassandra cluster is now up and normal"
    kubectl exec "$SEED_NODE" -- nodetool status
}

main(){
    if ! setup_dind-cluster; then
        test_failed
    elif ! kubectl_deploy; then
        test_failed
    elif ! verify_deploy; then
        test_failed
    else
        test_passed
    fi
}

main
