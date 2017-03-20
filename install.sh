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
bx login -a https://api.ng.bluemix.net -u ishangulhane55@gmail.com  -p Igulhane73 -s
bx cs cluster-create my-cassandra-cluster
bx cs workers my-cassandra-cluster
