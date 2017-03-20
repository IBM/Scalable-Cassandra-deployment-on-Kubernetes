#!/bin/sh

curl -L "https://cli.run.pivotal.io/stable?release=linux64-binary&source=github" | tar -zx
mv cf /usr/local/bin
curl -o /usr/share/bash-completion/completions/cf https://raw.githubusercontent.com/cloudfoundry/cli/master/ci/installers/completion/cf
cf --version
tar -xvf Bluemix_CLI.tar.gz
cd Bluemix_CLI
./install_bluemix_cli
