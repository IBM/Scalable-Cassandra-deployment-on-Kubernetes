#!/bin/sh

curl -L "https://cli.run.pivotal.io/stable?release=linux64-binary&source=github" | tar -zx
sudo mv cf /usr/local/bin
sudo curl -o /usr/share/bash-completion/completions/cf https://raw.githubusercontent.com/cloudfoundry/cli/master/ci/installers/completion/cf
cf --version
cf add-plugin-repo bluemix-cf https://plugins.ng.bluemix.net
cf install-plugin plugin_name -r bluemix-cf -f 
