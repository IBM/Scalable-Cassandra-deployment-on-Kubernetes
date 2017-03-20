#!/bin/sh

curl -L "https://cli.run.pivotal.io/stable?release=linux64-binary&source=github" | tar -zx
sudo mv cf /usr/local/bin
sudo curl -o /usr/share/bash-completion/completions/cf https://raw.githubusercontent.com/cloudfoundry/cli/master/ci/installers/completion/cf
cf --version
curl -L public.dhe.ibm.com/cloud/bluemix/cli/bluemix-cli/Bluemix_CLI_0.5.1_amd64.tar.gz > Bluemix_CLI.tar.gz
tar -xvf Bluemix_CLI.tar.gz
cd Bluemix_CLI
sudo ./install_bluemix_cli
bx plugin install container-service -r Bluemix
bx login -a https://api.ng.bluemix.net -u $BLUEMIX_USER -p $BLUEMIX_PASS
curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl
echo "kubectl installed!"
git clone https://github.com/IBM/cassandra-sample
cd cassandra-sample
echo "inside the cassandra-sample folder"
bx cs cluster-create --name "cassandra-demo"
sleep 600
bx cs workers cassandra-demo
$(bx cs cluster-config cassandra-demo | grep -v "Downloading" | grep -v "OK" | grep -v "The")
kubectl create -f cassandra-service.yaml
kubectl create -f cassandra-controller.yaml
echo "HEADLESS SERVICE and REPLICATION CONTROLLER CREATED!"
