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
cd Bluemix_CLI
sudo ./install_bluemix_cli
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
git clone https://github.com/IBM/kubernetes-container-service-cassandra-deployment.git
cd kubernetes-container-service-cassandra-deployment
kubectl delete --ignore-not-found=true -f cassandra-service.yaml
kubectl delete --ignore-not-found=true -f cassandra-controller.yaml
kubectl delete --ignore-not-found=true -f cassandra-statefulset.yaml
kubectl get svc
kubectl get pods
}

function run_tests() {
echo "Running tests"

kubectl create -f cassandra-service.yaml
kubectl create -f cassandra-controller.yaml

}

install_bluemix_cli
bluemix_auth
cluster_setup
run_tests

