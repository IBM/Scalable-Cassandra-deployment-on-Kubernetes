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
  echo "Y" | bx cs cluster-rm cassandra-demo
  bx cs cluster-create --name "cassandra-demo"
  git clone https://github.com/IBM/kubernetes-container-service-cassandra-deployment.git
  cd kubernetes-container-service-cassandra-deployment
  for i in `seq 1 6`;
        do
              check_clustersetup
        done
  kubectl get pods
  bx cs workers cassandra-demo
}

function check_clustersetup() {
  #statements
  echo "sleeping for 5m"
  sleep 5m
}

function kubectl_config() {
	echo "Installing and configuring kubectl"
	KUBECONFIG=$(bx cs cluster-config k8stest | awk  -F = '{print $2}' | tr -d '[:space:]')
	export KUBECONFIG
}


function run_tests() {
	echo "Running tests"
  git clone https://github.com/IBM/kubernetes-container-service-cassandra-deployment.git
  cd kubernetes-container-service-cassandra-deployment
  kubectl_config
  kubectl create -f cassandra-service.yaml
  kubectl create -f cassandra-controller.yaml
  echo "HEADLESS SERVICE and REPLICATION CONTROLLER CREATED!"

}

function exit_tests() {
	kubectl delete -f cassandra-service.yaml
	kubectl delete -f cassandra-controller.yaml
	echo "HEADLESS SERVICE and REPLICATION CONTROLLER DELETED!"
}


install_bluemix_cli
bluemix_auth
cluster_setup
run_tests
#exit_tests
