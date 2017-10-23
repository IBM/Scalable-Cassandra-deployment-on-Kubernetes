#!/bin/bash

kubectl_clean() {
    echo -e "Deleting previous version of wordpress if it exists"
    kubectl delete --ignore-not-found=true -f cassandra-service.yaml
    kubectl delete --ignore-not-found=true -f cassandra-controller.yaml
    kubectl delete --ignore-not-found=true -f cassandra-statefulset.yaml
    kuber=$(kubectl get pods -l app=cassandra)
    while [ ${#kuber} -ne 0 ]
    do
        sleep 5s
        kubectl get pods -l app=wordpress
        kuber=$(kubectl get pods -l app=cassandra)
    done
    echo "Cleaning done"
}

test_failed(){
    kubectl_clean
    echo -e >&2 "\033[0;31mKubernetes test failed!\033[0m"
    exit 1
}

test_passed(){
    kubectl_clean
    echo -e "\033[0;32mKubernetes test passed!\033[0m"
    exit 0
}

kubectl_config() {
    echo "Configuring kubectl"
    #shellcheck disable=SC2091
    $(bx cs cluster-config "$CLUSTER_NAME" | grep export)
}

kubectl_deploy() {
    kubectl_clean

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

verify_deploy() {
    # Check Cassandra Seed Node is running.
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

main() {
    if [[ "$TRAVIS_PULL_REQUEST" != false ]]; then
        echo -e "\033[0;33mPull request detected; not running Bluemix Container Service test.\033[0m"
        exit 0
    fi

    if ! kubectl_config; then
        echo "Config failed."
        test_failed
    elif ! kubectl_deploy; then
        echo "Deploy failed"
        test_failed
    elif ! verify_deploy; then
        test_failed
    else
        test_passed
    fi
}

main
