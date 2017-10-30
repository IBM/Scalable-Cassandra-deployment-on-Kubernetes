# Deploy with IBM Cloud Private

Follow the [instructions](https://github.com/IBM/deploy-ibm-cloud-private)
to either install a local instance of IBM Cloud private via Vagrant or a remote
instance at Softlayer. These instructions assume the former.

The local option uses Vagrant to create an instance of IBM Cloud Private within
a virtual machine.  The Vagrantfile in those instructions installs kubectl on
this VM.  To access your Vagrant VM:

```bash
$ vagrant ssh
```

From this promt inside the VM, clone this repo to make use of the included yaml
files.

```bash
$ git clone https://github.com/IBM/Scalable-Cassandra-deployment-on-Kubernetes.git
$ cd Scalable-Cassandra-deployment-on-Kubernetes
```

From here, you can follow along with the instructions in the
[root](../README.md#1-create-a-cassandra-headless-service#1-create-a-cassandra-headless-service) of this repo to deploy Cassandra.
