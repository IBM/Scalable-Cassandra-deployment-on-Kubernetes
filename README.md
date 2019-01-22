
[![Build Status](https://travis-ci.org/IBM/Scalable-Cassandra-deployment-on-Kubernetes.svg?branch=master)](https://travis-ci.org/IBM/Scalable-Cassandra-deployment-on-Kubernetes)

# Scalable multi-node Cassandra deployment on Kubernetes Cluster

*Read this in other languages: [한국어](README-ko.md)、[中国](README-cn.md).*

This project demonstrates the deployment of a multi-node scalable Cassandra cluster on Kubernetes. Apache Cassandra is a massively scalable open source NoSQL database. Cassandra is perfect for managing large amounts of structured, semi-structured, and unstructured data across multiple datacenters and the cloud.

Leveraging Kubernetes concepts such as [PersistentVolume](https://kubernetes.io/docs/concepts/storage/persistent-volumes/) and [StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/), we can provide a resilient installation of Cassandra and be confident that its data (state) are safe.

We also utilize a ["headless" service](https://kubernetes.io/docs/concepts/services-networking/service/#headless-services) for Cassandra. This way we can provide a way for applications to access it via [KubeDNS](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/) and not expose it to the outside world. To access it from your developer workstation you can use `kubectl exec` commands against any of the cassandra pods. If you do wish to connect an application to it you can use the KubeDNS value of `cassandra.default.svc.cluster.local` when configuring your application.

![kube-cassandra](images/kube-cassandra-code.png)

## Kubernetes Concepts Used

* [Kubenetes Pods](https://kubernetes.io/docs/concepts/workloads/pods/pod/)
* [Kubenetes Services](https://kubernetes.io/docs/concepts/services-networking/service/)
* [Kubernets StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)

## Included Components
* [Kubernetes Clusters](https://cloud.ibm.com/docs/containers/cs_ov.html#cs_ov)
* [Bluemix container service](https://cloud.ibm.com/catalog?taxonomyNavigation=apps&category=containers)
* [IBM Cloud Private](https://www.ibm.com/cloud/private)
* [Cassandra](https://cassandra.apache.org/)

## Getting Started

In order to follow this guide you'll need a Kubernetes cluster. If you do not have access to an existing Kubernetes cluster then follow the instructions (in the link) for one of the following:

* [Minikube](https://kubernetes.io/docs/setup/minikube/) on your workstation
* [IBM Bluemix Container Service](https://github.com/IBM/container-journey-template#container-journey-template---creating-a-kubernetes-cluster) to deploy in an IBM managed cluster (free small cluster)
* [IBM Cloud Private - Community Edition](https://github.com/IBM/deploy-ibm-cloud-private/blob/master/README.md) for a self managed Kubernetes Cluster (in Vagrant, Softlayer or OpenStack)

_The code here is regularly tested against [Kubernetes Cluster from Bluemix Container Service](https://cloud.ibm.com/docs/containers/cs_ov.html#cs_ov) using Travis CI._

After installing (or setting up your access to) Kubernetes ensure that you can access it by running the following and confirming you get version responses for both the Client and the Server:

```shell
$ kubectl version
Client Version: version.Info{Major:"1", Minor:"7", GitVersion:"v1.7.5", GitCommit:"17d7182a7ccbb167074be7a87f0a68bd00d58d97", GitTreeState:"clean", BuildDate:"2017-08-31T09:14:02Z", GoVersion:"go1.8.3", Compiler:"gc", Platform:"linux/amd64"}
Server Version: version.Info{Major:"1", Minor:"7", GitVersion:"v1.7.5", GitCommit:"17d7182a7ccbb167074be7a87f0a68bd00d58d97", GitTreeState:"clean", BuildDate:"2017-09-18T20:30:29Z", GoVersion:"go1.8.3", Compiler:"gc", Platform:"linux/amd64"}
```

## Create a Cassandra Service for Cassandra cluster formation and discovery

### 1. Create a Cassandra Headless Service

To allow us to do simple discovery of the cassandra seed node (which we will deploy shortly) we can create a "headless" service.  We do this by  specifying **none** for the  **clusterIP** in the [cassandra-service.yaml](cassandra-service.yaml). This headless service  allows us to use KubeDNS for the Pods to discover the IP address of the Cassandra seed.

You can create the headless service using the [cassandra-service.yaml](cassandra-service.yaml) file:

```shell
$ kubectl create -f cassandra-service.yaml
service "cassandra" created
$ kubectl get svc cassandra
NAME        CLUSTER-IP   EXTERNAL-IP   PORT(S)    AGE
cassandra   None         <none>        9042/TCP   10s
```

Most applications deployed to Kubernetes should be cloud native and rely on external resources for their data (or state). However since Cassandra is a database we can use Stateful sets and Persistent Volumes to ensure resiliency in our database.

### 2. Create Local Volumes

To create persistent Cassandra nodes, we need to provision Persistent Volumes. There are two ways to provision PV's: **dynamically and statically**.

For the sake of simplicity and compatibility we will use **Static** provisioning where we will create volumes manually using the provided yaml files.

_note: You'll need to have the same number of Persistent Volumes as the number of your Cassandra nodes. If you are expecting to have 3 Cassandra nodes, you'll need to create 3 Persistent Volumes._

The provided [local-volumes.yaml](local-volumes.yaml) file already has **3** Persistent Volumes defined. Update the file to add more if you expect to have greater than 3 Cassandra nodes. Create the volumes:

```shell
$ kubectl create -f local-volumes.yaml
$ kubectl get pv
NAME               CAPACITY   ACCESSMODES   RECLAIMPOLICY   STATUS      CLAIM     STORAGECLASS   REASON    AGE
cassandra-data-1   1Gi        RWO           Recycle         Available                                      7s
cassandra-data-2   1Gi        RWO           Recycle         Available                                      7s
cassandra-data-3   1Gi        RWO           Recycle         Available                                      7s
```

### 3. Create a StatefulSet

The [StatefulSet](cassandra-statefulset.yaml) is responsible for creating the Pods. It provides ordered deployment, ordered termination and unique network names. Run the following command to start a single Cassandra server:

```shell
$ kubectl create -f cassandra-statefulset.yaml
```
### 4. Validate the StatefulSet

You can check if your StatefulSet has deployed using the command below.

```shell
$ kubectl get statefulsets
NAME        DESIRED   CURRENT   AGE
cassandra   1         1         2h
```

If you view the list of the Pods, you should see 1 Pod running. Your Pod name should be cassandra-0 and the next pods would follow the ordinal number (*cassandra-1, cassandra-2,..*) Use this command to view the Pods created by the StatefulSet:

```shell
$ kubectl get pods -o wide
NAME          READY     STATUS    RESTARTS   AGE       IP              NODE
cassandra-0   1/1       Running   0          1m        172.xxx.xxx.xxx   169.xxx.xxx.xxx
```

To check if the Cassandra node is up, perform a **nodetool status:**

```shell
$ kubectl exec -ti cassandra-0 -- nodetool status
Datacenter: DC1
===============
Status=Up/Down
|/ State=Normal/Leaving/Joining/Moving
--  Address          Load       Tokens       Owns (effective)   Host ID                               Rack
UN  172.xxx.xxx.xxx  109.28 KB  256          100.0%             6402e90d-7995-4ee1-bb9c-36097eb2c9ec  Rack1
```
### 5. Scale the StatefulSet

To increase or decrease the size of your StatefulSet you can use the scale command:

```shell
$ kubectl scale --replicas=3 statefulset/cassandra
```

Wait a minute or two and check if it worked:

```shell
$ kubectl get statefulsets
NAME        DESIRED   CURRENT   AGE
cassandra   3         3         2h
```

If you watch the Cassandra pods deploy, they should be created sequentially.

You can view the list of the Pods again to confirm that your Pods are up and running.

```shell
$ kubectl get pods -o wide
NAME          READY     STATUS    RESTARTS   AGE       IP                NODE
cassandra-0   1/1       Running   0          13m       172.xxx.xxx.xxx   169.xxx.xxx.xxx
cassandra-1   1/1       Running   0          38m       172.xxx.xxx.xxx   169.xxx.xxx.xxx
cassandra-2   1/1       Running   0          38m       172.xxx.xxx.xxx   169.xxx.xxx.xxx
```

You can perform a **nodetool status** to check if the other cassandra nodes have joined and formed a Cassandra cluster.

_**Note:** It can take around 5 minutes for the Cassandra database to finish its setup._

```shell
$ kubectl exec -ti cassandra-0 -- nodetool status
Datacenter: DC1
===============
Status=Up/Down
|/ State=Normal/Leaving/Joining/Moving
--  Address     Load       Tokens       Owns (effective)  Host ID                               Rack
UN  172.xxx.xxx.xxx  103.25 KiB  256          68.7%             633ae787-3080-40e8-83cc-d31b62f53582  Rack1
UN  172.xxx.xxx.xxx  108.62 KiB  256          63.5%             e95fc385-826e-47f5-a46b-f375532607a3  Rack1
UN  172.xxx.xxx.xxx  177.38 KiB  256          67.8%             66bd8253-3c58-4be4-83ad-3e1c3b334dfd  Rack1
```

_You will need to wait for the status of the nodes to be Up and Normal (UN) to execute the commands in the next steps._

### 6. Using CQL

You can access the cassandra container using the following command:

```shell
kubectl exec -it cassandra-0 cqlsh
Connected to Cassandra at 127.0.0.1:9042.
[cqlsh 5.0.1 | Cassandra 3.11.1 | CQL spec 3.4.4 | Native protocol v4]
Use HELP for help.
cqlsh> describe tables

Keyspace system_traces
----------------------
events  sessions

Keyspace system_schema
----------------------
tables     triggers    views    keyspaces  dropped_columns
functions  aggregates  indexes  types      columns

Keyspace system_auth
--------------------
resource_role_permissons_index  role_permissions  role_members  roles

Keyspace system
---------------
available_ranges          peers               batchlog        transferred_ranges
batches                   compaction_history  size_estimates  hints
prepared_statements       sstable_activity    built_views
"IndexInfo"               peer_events         range_xfers
views_builds_in_progress  paxos               local

Keyspace system_distributed
---------------------------
repair_history  view_build_status  parent_repair_history

```

## License
This code pattern is licensed under the Apache Software License, Version 2.  Separate third party code objects invoked within this code pattern are licensed by their respective providers pursuant to their own separate licenses. Contributions are subject to the [Developer Certificate of Origin, Version 1.1 (DCO)](https://developercertificate.org/) and the [Apache Software License, Version 2](https://www.apache.org/licenses/LICENSE-2.0.txt).

[Apache Software License (ASL) FAQ](https://www.apache.org/foundation/license-faq.html#WhatDoesItMEAN)

## Troubleshooting

* If your Cassandra instance is not running properly, you may check the logs using
	* `kubectl logs <your-pod-name>`
* To clean/delete your data on your Persistent Volumes, delete your PVCs using
	* `kubectl delete pvc -l app=cassandra`
* If your Cassandra nodes are not joining, delete your controller/statefulset then delete your Cassandra service.
	* `kubectl delete statefulset cassandra` if you created the Cassandra StatefulSet
	* `kubectl delete svc cassandra`
* To delete everything:
	* `kubectl delete statefulset,pvc,pv,svc -l app=cassandra`

## References
* This Cassandra example is based on Kubernete's [Cloud Native Deployments of Cassandra using Kubernetes](https://github.com/kubernetes/examples/tree/master/cassandra).
