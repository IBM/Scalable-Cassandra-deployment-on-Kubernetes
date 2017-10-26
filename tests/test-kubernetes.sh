#!/bin/bash

# This script is intended to be run by Travis CI. If running elsewhere, invoke
# it with: TRAVIS_PULL_REQUEST=false [path to script]
# CLUSTER_NAME must be set prior to running (see environment variables in the
# Travis CI documentation).

# shellcheck disable=SC1090
source "$(dirname "$0")"/../scripts/resources.sh

kubectl_clean() {
    echo -e "Deleting previous version of cassandra if it exists"
    kubectl delete --ignore-not-found=true -f cassandra-service.yaml
    kubectl delete --ignore-not-found=true -f cassandra-controller.yaml
    kubectl delete --ignore-not-found=true -f cassandra-statefulset.yaml
    kuber=$(kubectl get pods -l app=cassandra)
    while [ ${#kuber} -ne 0 ]
    do
        sleep 5s
        kubectl get pods -l app=cassandra
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
  kubeclt_clean

  echo "Running scripts/quickstart.sh"
  "$(dirname "$0")"/../scripts/quickstart.sh

    echo "Waiting for pods to be running"
    i=0
    while [[ $(kubectl get pods -l app=cassandra | grep -c Running) -ne 1 ]]; do
      if [[ ! "$i" -lt 24 ]]; then
          echo "Timeout waiting on pods to be ready"
          test_failed "$0"
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

main(){
    is_pull_request "$0"

    if ! kubectl_config; then
        test_failed "$0"
    elif ! kubectl_deploy; then
        test_failed "$0"
    elif ! verify_deploy; then
        test_failed "$0"
    else
        test_passed "$0"
    fi
}

main
