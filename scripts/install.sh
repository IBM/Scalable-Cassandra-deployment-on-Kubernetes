#!/bin/sh

function install_bluemix_cli() {
#statements
echo "Installing Bluemix cli"
curl -L "https://cli.run.pivotal.io/stable?release=linux64-binary&source=github" | tar -zx
sudo mv cf /usr/local/bin
sudo curl -o /usr/share/bash-completion/completions/cf https://raw.githubusercontent.com/cloudfoundry/cli/master/ci/installers/completion/cf
cf --version
curl -L public.dhe.ibm.com/cloud/bluemix/cli/bluemix-cli/Bluemix_CLI_0.5.1_amd64.tar.gz > Bluemix_CLI.tar.gz
tar -xvf Bluemix_CLI.tar.gz
sudo ./Bluemix_CLI/install_bluemix_cli
}

function bluemix_auth() {
echo "Authenticating with Bluemix"
echo "1" | bx login -a https://api.ng.bluemix.net -u $BLUEMIX_USER -p $BLUEMIX_PASS
curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
bx plugin install container-service -r Bluemix
echo "Installing kubectl"
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl
}

function cluster_setup() {
bx cs workers cassandra-demo
$(bx cs cluster-config cassandra-demo | grep export)
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
}

function run_tests() {
echo "Running tests"

echo -e "Creating headless service..."
kubectl create -f cassandra-service.yaml

echo -e "Creating Replication Controller..."
kubectl create -f cassandra-controller.yaml

SEED_NODE=$(kubectl get pods | grep cassandra | awk '{print $1}')
echo "Seed node is ${SEED_NODE}"
echo "Waiting for Cassansdra Pod to initialize..."
sleep 30s


STATUS=$(kubectl exec $SEED_NODE -- nodetool status | grep UN)

while [ ${#STATUS} -eq 0 ]
do
    echo "Waiting for Cassandra to finish setting up..."
    sleep 10s
    STATUS=$(kubectl exec $SEED_NODE -- nodetool status | grep UN)
done

echo "Cassandra Node is UP and NORMAL"
kubectl exec $SEED_NODE -- nodetool status

echo "Scaling the Replication Controller..."
kubectl scale rc cassandra --replicas=4

sleep 5s

TEST=$(kubectl exec $SEED_NODE -- nodetool status | grep UN | awk '{print $1}')

while [ "${#TEST}" != "11" ]
do
kubectl exec $SEED_NODE -- nodetool status
# echo ${#TEST}
echo "Waiting for all Cassandra nodes to join and set up."

sleep 5s
TEST=$(kubectl exec $SEED_NODE -- nodetool status | grep UN | awk '{print $1}')
done

echo "Your cassandra cluster is now up and normal"
kubectl exec $SEED_NODE -- nodetool status
echo "Travis build has finished. Cleaning up..."
}

install_bluemix_cli
bluemix_auth
cluster_setup
run_tests
cluster_setup
