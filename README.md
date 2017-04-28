
[![Build Status](https://travis-ci.org/IBM/scalable-cassandra-deployment-on-kubernetes.svg?branch=master)](https://travis-ci.org/IBM/scalable-cassandra-deployment-on-kubernetes)

# Scalable multi-node Cassandra using Kubernetes Cluster

This project demonstrates the deployment of a multi-node scalable Cassandra cluster on Kubernetes. Apache Cassandra is a massively scalable open source NoSQL database. Cassandra is perfect for managing large amounts of structured, semi-structured, and unstructured data across multiple datacenters and the cloud.

In this journey we show a cloud native Cassandra deployment on Kubernetes. Cassandra understands that it is running within a cluster manager, and uses this cluster management infrastructure to help implement the application.

Leveraging Kubernetes concepts like Replication Controller, StatefulSets we provide step by step instructions to deploy either non-persistent or persistent Cassandra clusters on top of Bluemix Container Service using Kubernetes cluster

![kube-cassandra](images/kube-cassandra-code.png)

## Kubernetes Concepts Used

- [Kubenetes Pods](https://kubernetes.io/docs/user-guide/pods)
- [Kubenetes Services](https://kubernetes.io/docs/user-guide/services)
- [Kubernetes Replication Controller](https://kubernetes.io/docs/user-guide/replication-controller/)
- [Kubernets StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)

## Included Components
- [Kubernetes Clusters](https://console.ng.bluemix.net/docs/containers/cs_ov.html#cs_ov)
- [Bluemix container service](https://console.ng.bluemix.net/catalog/?taxonomyNavigation=apps&category=containers)
- [Bluemix DevOps Toolchain Service](https://console.ng.bluemix.net/catalog/services/continuous-delivery)
- [Cassandra](http://cassandra.apache.org/)

## Prerequisite

Create a Kubernetes cluster with either [Minikube](https://kubernetes.io/docs/getting-started-guides/minikube) for local testing, or with [IBM Bluemix Container Service](https://github.com/IBM/container-journey-template) to deploy in cloud. The code here is regularly tested against [Kubernetes Cluster from Bluemix Container Service](https://console.ng.bluemix.net/docs/containers/cs_ov.html#cs_ov) using Travis.

## Deploy to Bluemix
If you want to deploy Cassandra nodes directly to Bluemix, click on 'Deploy to Bluemix' button below to create a Bluemix DevOps service toolchain and pipeline for deploying the sample, else jump to [Steps](#steps)

> You will need to create your Kubernetes cluster first and make sure it is fully deployed in your Bluemix account.

[![Create Toolchain](https://github.com/IBM/container-journey-template/blob/master/images/button.png)](https://console.ng.bluemix.net/devops/setup/deploy/?repository=https://github.com/IBM/scalable-cassandra-deployment-on-kubernetes)

Please follow the [Toolchain instructions](https://github.com/IBM/container-journey-template/blob/master/Toolchain_Instructions.md) to complete your toolchain and pipeline.

The Cassandra cluster will not be exposed on the public IP of the Kubernetes cluster. You can still access them by exporting your Kubernetes cluster configuration using `bx cs cluster-config <your-cluster-name>` and doing [Step 5](#5-using-cql) or to simply check their status `kubectl exec <POD-NAME> -- nodetool status`

## Steps

### Create a Cassandra Service for Cassandra cluster formation and discovery

1. [Create a Cassandra Headless Service](#1-create-a-cassandra-headless-service)

### Use Replication Controller to create non-persistent Cassandra cluster

2. [Create a Replication Controller](#2-create-a-replication-controller)
3. [Validate the Replication Controller](#3-validate-the-replication-controller)
4. [Scale the Replication Controller](#4-scale-the-replication-controller)
5. [Using Cassandra Query Language (CQL)](#5-using-cql)

### Use StatefulSets to create persistent Cassandra cluster

6. [Create Local Volumes](#6-create-local-volumes)
7. [Create a StatefulSet](#7-create-a-statefulset)
8. [Validate the StatefulSet](#8-validate-the-statefulset)
9. [Scale the StatefulSet](#9-scale-the-statefulset)
10. [Using Cassandra Query Language(CQL)](#10-using-cql)

#### [Troubleshooting](#troubleshooting-1)


# 1. Create a Cassandra Headless Service
In this sample app you don’t need load-balancing and a single service IP. In this case, you can create “headless” service by specifying **none** for the  **clusterIP**. We'll need the headless service for the Pods to discover the IP address of the Cassandra seed.
Here is the Service description for the headless Service:
```yaml
apiVersion: v1
kind: Service
metadata:
  labels:
    app: cassandra
  name: cassandra
spec:
  clusterIP: None
  ports:
    - port: 9042
  selector:
    app: cassandra
```
You can create the headless service using the provided yaml file:
```bash
$ kubectl create -f cassandra-service.yaml
service "cassandra" created
```

If you want to create a persistent Cassandra cluster using StatefulSets, please jump to [Step 6](#6-create-local-volumes)

# 2. Create a Replication Controller
The Replication Controller is the one responsible for creating or deleting pods to ensure the number of Pods match its defined number in "replicas". The Pods' template are defined inside the Replication Controller. You can set how much resources will be used for each pod inside the template and limit the resources they can use. Here is the Replication Controller description:
```yaml
apiVersion: v1
kind: ReplicationController
metadata:
  name: cassandra
  # The labels will be applied automatically
  # from the labels in the pod template, if not set
  # labels:
    # app: cassandra
spec:
  replicas: 1
  # The selector will be applied automatically
  # from the labels in the pod template, if not set.
  # selector:
      # app: cassandra
  template:
    metadata:
      labels:
        app: cassandra
    spec:
      containers:
        - env:
            - name: CASSANDRA_SEED_DISCOVERY
              value: cassandra
            # CASSANDRA_SEED_DISCOVERY should match the name of the service in cassandra-service.yaml

            - name: CASSANDRA_CLUSTER_NAME
              value: Cassandra
            - name: CASSANDRA_DC
              value: DC1
            - name: CASSANDRA_RACK
              value: Rack1
            - name: CASSANDRA_ENDPOINT_SNITCH
              value: GossipingPropertyFileSnitch
          image: docker.io/anthonyamanse/cassandra-demo:7.0
          name: cassandra
          ports:
            - containerPort: 7000
              name: intra-node
            - containerPort: 7001
              name: tls-intra-node
            - containerPort: 7199
              name: jmx
            - containerPort: 9042
              name: cql
          volumeMounts:
            - mountPath: /var/lib/cassandra/data
              name: data
      volumes:
        - name: data
          emptyDir: {}
```
 You can create a Replication Controller using the provided yaml file with 1 replica:
```bash
$ kubectl create -f cassandra-controller.yaml
replicationcontroller "cassandra" created
```

# 3. Validate the Replication Controller
You can view a list of Replication Controllers using this command:
```bash
$ kubectl get rc
NAME        DESIRED   CURRENT   READY     AGE
cassandra   1         1         1         1m
```
If you view the list of the Pods, you should see 1 Pod running. Use this command to view the Pods created by the Replication Controller:

```bash
$ kubectl get pods -o wide
NAME              READY     STATUS    RESTARTS   AGE       IP              NODE
cassandra-xxxxx   1/1       Running   0          1m        172.xxx.xxx.xxx   169.xxx.xxx.xxx
```

To check if the Cassandra node is up, perform a **nodetool status:**
> You may not be able to run this command for some time if the Pod hasn't created the container yet or the Cassandra instance hasn't finished setting up.

```bash
$ kubectl exec -ti cassandra-xxxxx -- nodetool status
Datacenter: DC1
===============
Status=Up/Down
|/ State=Normal/Leaving/Joining/Moving
--  Address          Load       Tokens       Owns (effective)   Host ID                               Rack
UN  172.xxx.xxx.xxx  109.28 KB  256          100.0%             6402e90d-7995-4ee1-bb9c-36097eb2c9ec  Rack1
```

To increase the number of Pods, you can scale the Replication Controller as many as the available resources can acccomodate. Proceed to the next step.

# 4. Scale the Replication Controller

To scale the Replication Controller, use this command:
```bash
$ kubectl scale rc cassandra --replicas=4
replicationcontroller "cassandra" scaled
```
After scaling, you should see that your desired number has increased.
```bash
$ kubectl get rc
NAME        DESIRED   CURRENT   READY     AGE
cassandra   4         4         4         3m
```
You can view the list of the Pods again to confirm that your Pods are up and running.
```bash
$ kubectl get pods -o wide
NAME              READY     STATUS    RESTARTS   AGE       IP                NODE
cassandra-1lt0j   1/1       Running   0          13m       172.xxx.xxx.xxx   169.xxx.xxx.xxx
cassandra-vsqx4   1/1       Running   0          38m       172.xxx.xxx.xxx   169.xxx.xxx.xxx
cassandra-jjx52   1/1       Running   0          38m       172.xxx.xxx.xxx   169.xxx.xxx.xxx
cassandra-wzlxl   1/1       Running   0          38m       172.xxx.xxx.xxx   169.xxx.xxx.xxx
```

You can check that the Pods are visible to the Service using the following service endpoints query:
```bash
$ kubectl get endpoints cassandra -o yaml
apiVersion: v1
kind: Endpoints
metadata:
  creationTimestamp: 2017-03-15T19:53:09Z
  labels:
    app: cassandra
  name: cassandra
  namespace: default
  resourceVersion: "10591"
  selfLink: /api/v1/namespaces/default/endpoints/cassandra
  uid: 03e992ca-09b9-11e7-b645-daaa1d04f9b2
subsets:
- addresses:
  - ip: 172.xxx.xxx.xxx
    nodeName: 169.xxx.xxx.xxx
    targetRef:
      kind: Pod
      name: cassandra-xp2jx
      namespace: default
      resourceVersion: "10583"
      uid: 4ee1d4e2-09b9-11e7-b645-daaa1d04f9b2
  - ip: 172.xxx.xxx.xxx
    nodeName: 169.xxx.xxx.xxx
    targetRef:
      kind: Pod
      name: cassandra-gs64p
      namespace: default
      resourceVersion: "10589"
      uid: 4ee2025b-09b9-11e7-b645-daaa1d04f9b2
  - ip: 172.xxx.xxx.xxx
      nodeName: 169.xxx.xxx.xxx
      targetRef:
        kind: Pod
        name: cassandra-g5wh8
        namespace: default
        resourceVersion: "109410"
        uid: a39ab3ce-0b5a-11e7-b26d-665c3f9e8d67
    - ip: 172.xxx.xxx.xxx
      nodeName: 169.xxx.xxx.xxx
      targetRef:
        kind: Pod
        name: cassandra-gf37p
        namespace: default
        resourceVersion: "109418"
        uid: a39abcb9-0b5a-11e7-b26d-665c3f9e8d67
    ports:
    - port: 9042
      protocol: TCP
```

You can perform a **nodetool status** to check if the other cassandra nodes have joined and formed a Cassandra cluster. **Substitute the Pod name to the one you have:**
```bash
$ kubectl exec -ti cassandra-xxxxx -- nodetool status
Datacenter: DC1
===============
Status=Up/Down
|/ State=Normal/Leaving/Joining/Moving
--  Address          Load       Tokens       Owns (effective)  Host ID                               Rack
UN  172.xxx.xxx.xxx  109.28 KB  256          50.0%             6402e90d-7995-4ee1-bb9c-36097eb2c9ec  Rack1
UN  172.xxx.xxx.xxx  196.04 KB  256          51.4%             62eb2a08-c621-4d9c-a7ee-ebcd3c859542  Rack1
UN  172.xxx.xxx.xxx  114.44 KB  256          46.2%             41e7d359-be9b-4ff1-b62f-1d04aa03a40c  Rack1
UN  172.xxx.xxx.xxx  79.83 KB   256          52.4%             fb1dd881-0eff-4883-88d0-91ee31ab5f57  Rack1
```



# 5. Using CQL
> **Note:** It can take around 5 minutes for the Cassandra database to finish its setup.

You can check if the Cassandra nodes are up and running by using this command:
**Substitute the Pod name to the one you have**
```bash
$ kubectl exec cassandra-xxxxx -- nodetool status
Datacenter: DC1
===============
Status=Up/Down
|/ State=Normal/Leaving/Joining/Moving
--  Address          Load       Tokens       Owns (effective)  Host ID                               Rack
UN  172.xxx.xxx.xxx  109.28 KB  256          50.0%             6402e90d-7995-4ee1-bb9c-36097eb2c9ec  Rack1
UN  172.xxx.xxx.xxx  196.04 KB  256          51.4%             62eb2a08-c621-4d9c-a7ee-ebcd3c859542  Rack1
UN  172.xxx.xxx.xxx  114.44 KB  256          46.2%             41e7d359-be9b-4ff1-b62f-1d04aa03a40c  Rack1
UN  172.xxx.xxx.xxx  79.83 KB   256          52.4%             fb1dd881-0eff-4883-88d0-91ee31ab5f57  Rack1
```
> You will need to wait for the status of the nodes to be Up and Normal (UN) to execute the commands in the next steps.


You can access the cassandra container using the following command:

```bash
$ kubectl exec -it cassandra-xxxxx /bin/bash
root@cassandra-xxxxx:/# ls
bin  boot  dev	docker-entrypoint.sh  etc  home  initial-seed.cql  lib	lib64  media  mnt  opt	proc  root  run  sbin  srv  sys  tmp  usr  var
```

Now run the sample .cql file to create and update employee table on cassandra keyspace using the following commands:
> You only need to run the .cql file **once** in **ONE** Cassandra node. The other pods should also have access to the sample table created by the .cql file.

```bash
root@cassandra-xxxxx:/# cqlsh -f initial-seed.cql
root@cassandra-xxxxx:/# cqlsh
Connected to Test Cluster at 127.0.0.1:9042.
[cqlsh 5.0.1 | Cassandra 3.10 | CQL spec 3.4.4 | Native protocol v4]
Use HELP for help.
cqlsh> DESCRIBE TABLES

Keyspace my_cassandra_keyspace
------------------------------
employee

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

Keyspace system_traces
----------------------
events  sessions

cqlsh> SELECT * FROM my_cassandra_keyspace.employee;

 emp_id | emp_city | emp_name | emp_phone  | emp_sal
--------+----------+----------+------------+---------
      1 |       SF |    David | 9848022338 |   50000
      2 |      SJC |    Robin | 9848022339 |   40000
      3 |   Austin |      Bob | 9848022330 |   45000
```

You now have a non-persistent Caasandra cluster ready!!

**If you want to create persistent Cassandra clusters, pelase move forward. Before proceeding to the next steps, delete your Cassandra Replication Controller.**

```bash
$ kubectl delete rc cassandra
```
# 6. Create Local Volumes

If you have not done it before, please [create a Cassandra Headless Service](#1-create-a-cassandra-headless-service) before moving forward.

To create persistent Cassandra nodes, we need to provision Persistent Volumes. There are two ways to provision PV's: **dynamically and statically**.

For **Dynamic** provisioning, you'll need to have **StorageClasses** and you'll need to have a **paid** Kubernetes cluster service. In this journey, we will use **Static** provisioning where we will create volumes manually using the provided yaml files. **You'll need to have the same number of Persistent Volumes as the number of your Cassandra nodes.**
> Example: If you are expecting to have 4 Cassandra nodes, you'll need to create 4 Persistent Volumes

The provided yaml file already has **4** Persistent Volumes defined. Configure them to add more if you expect to have greater than 4 Cassandra nodes.
```bash
$ kubectl create -f local-volumes.yaml
```

You will use the same service you created earlier.

# 7. Create a StatefulSet
> Make sure you have deleted your Replication Controller if it is still running. `kubectl delete rc cassandra`

The StatefulSet is the one responsible for creating the Pods. It has the features of ordered deployment, ordered termination and unique network names. You will start with a single Cassandra node using StatefulSet. Run the following command.
```bash
$ kubectl create -f cassandra-statefulset.yaml
```
# 8. Validate the StatefulSet

You can check if your StatefulSet has deployed using the command below.
```bash
$ kubectl get statefulsets
NAME        DESIRED   CURRENT   AGE
cassandra   1         1         2h
```
If you view the list of the Pods, you should see 1 Pod running. Your Pod name should be cassandra-0 and the next pods would follow the ordinal number (*cassandra-1, cassandra-2,..*) Use this command to view the Pods created by the StatefulSet:

```bash
$ kubectl get pods -o wide
NAME          READY     STATUS    RESTARTS   AGE       IP              NODE
cassandra-0   1/1       Running   0          1m        172.xxx.xxx.xxx   169.xxx.xxx.xxx
```

To check if the Cassandra node is up, perform a **nodetool status:**

```bash
$ kubectl exec -ti cassandra-0 -- nodetool status
Datacenter: DC1
===============
Status=Up/Down
|/ State=Normal/Leaving/Joining/Moving
--  Address          Load       Tokens       Owns (effective)   Host ID                               Rack
UN  172.xxx.xxx.xxx  109.28 KB  256          100.0%             6402e90d-7995-4ee1-bb9c-36097eb2c9ec  Rack1
```
# 9. Scale the StatefulSet
To increase or decrease the size of your StatefulSet, use this command:
```bash
$ kubectl edit statefulset cassandra
```
You should be redirected to and editor in your terminal. You need to edit the line where it says `replicas: 1` and change it to `replicas: 4` Save it and the StatefulSet should now have 4 Pods
After scaling, you should see that your desired number has increased.
```bash
$ kubectl get statefulsets
NAME        DESIRED   CURRENT   AGE
cassandra   4         4         2h
```
If you watch the Cassandra pods deploy, they should be created sequentially.

You can view the list of the Pods again to confirm that your Pods are up and running.
```bash
$ kubectl get pods -o wide
NAME          READY     STATUS    RESTARTS   AGE       IP                NODE
cassandra-0   1/1       Running   0          13m       172.xxx.xxx.xxx   169.xxx.xxx.xxx
cassandra-1   1/1       Running   0          38m       172.xxx.xxx.xxx   169.xxx.xxx.xxx
cassandra-2   1/1       Running   0          38m       172.xxx.xxx.xxx   169.xxx.xxx.xxx
cassandra-3   1/1       Running   0          38m       172.xxx.xxx.xxx   169.xxx.xxx.xxx
```
You can perform a **nodetool status** to check if the other cassandra nodes have joined and formed a Cassandra cluster.
```bash
$ kubectl exec -ti cassandra-0 -- nodetool status
Datacenter: DC1
===============
Status=Up/Down
|/ State=Normal/Leaving/Joining/Moving
--  Address          Load       Tokens       Owns (effective)  Host ID                               Rack
UN  172.xxx.xxx.xxx  109.28 KB  256          50.0%             6402e90d-7995-4ee1-bb9c-36097eb2c9ec  Rack1
UN  172.xxx.xxx.xxx  196.04 KB  256          51.4%             62eb2a08-c621-4d9c-a7ee-ebcd3c859542  Rack1
UN  172.xxx.xxx.xxx  114.44 KB  256          46.2%             41e7d359-be9b-4ff1-b62f-1d04aa03a40c  Rack1
UN  172.xxx.xxx.xxx  79.83 KB   256          52.4%             fb1dd881-0eff-4883-88d0-91ee31ab5f57  Rack1
```


# 10. Using CQL
You can do [Step 5](#5-using-cql) again to use CQL in your Cassandra Cluster deployed with StatefulSet.


## Troubleshooting

* If your Cassandra instance is not running properly, you may check the logs using
	* `kubectl logs <your-pod-name>`
* To clean/delete your data on your Persistent Volumes, delete your PVCs using
	* `kubectl delete pvc -l app=cassandra`
* If your Cassandra nodes are not joining, delete your controller/statefulset then delete your Cassandra service.
	* `kubectl delete rc cassandra` if you created the Cassandra Replication Controller
	* `kubectl delete statefulset cassandra` if you created the Cassandra StatefulSet
	* `kubectl delete svc cassandra`
* To delete everything:
	* `kubectl delete rc,statefulset,pvc,svc -l app=cassnadra`
	* `kubectl delete pv -l tpye=local`

## References
* This Cassandra example is based on Kubernete's [Cloud Native Deployments of Cassandra using Kubernetes](https://github.com/kubernetes/kubernetes/tree/master/examples/storage/cassandra).

## License

[Apache 2.0](http://www.apache.org/licenses/LICENSE-2.0)
