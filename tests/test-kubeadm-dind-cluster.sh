#!/bin/bash -e

# shellcheck disable=SC1090
source "$(dirname "$0")"/../scripts/resources.sh

setup_dind-cluster() {
    wget https://cdn.rawgit.com/Mirantis/kubeadm-dind-cluster/master/fixed/dind-cluster-v1.7.sh
    chmod 0755 dind-cluster-v1.7.sh
    ./dind-cluster-v1.7.sh up
    export PATH="$HOME/.kubeadm-dind-cluster:$PATH"
}

kubectl_deploy() {
  echo "Running scripts/quickstart.sh"
  "$(dirname "$0")"/../scripts/quickstart.sh

  echo "Waiting for pods to be running"
  i=0
  while [[ $(kubectl get pods | grep -c Running) -ne 1 ]]; do
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
