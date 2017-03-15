# Container Service Cassandra Sample

This tutorial demonstrates the deployment of Cassandra on Kubernetes. With IBM® Bluemix® Container Service, you can deploy and manage your own Kubernetes cluster in the cloud that lets you automate the deployment, operation, scaling, and monitoring of containerized apps over a cluster of independent compute hosts called worker nodes. 


## Prerequisite

* Create a Kubernetes cluster with IBM Bluemix Container Service. 

	* If you have not setup the Kubernetes cluster, please follow the [Creating a Kubernetes cluster](https://github.com/IBM/container-service-wordpress-sample/blob/master/creating-a-kubernetes-cluster.md) tutorial.

* Clone this repository for the necessary files and go inside the directory

	```bash
    $ git clone https://github.com/IBM/container-service-cassandra-sample.git
    $ cd container-service-cassandra-sample
    ```

## Objectives

This scenario provides instructions for the following tasks:

- Create a replication controller to create Cassandra node pods
- Validate and Scale the replication controller
- Use Cassandra Query Language

## Audience

This tutorial is intended for software developers who have never deployed an application on Kubernetes cluster before.

# 1. Create a Cassandra Headless Service
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
For now, you don't need any load-balancing or proxying done in this sample app. You can create the headless service using the provided yaml file:
```bash
$ kubectl create -f cassandra-service.yaml
service "cassandra" created
```
# 2. Create a Replication Controller
Here is the Replication Controller description:
```yaml
apiVersion: v1
kind: ReplicationController
metadata:
  labels:
    app: cassandra
  name: cassandra
spec:
  replicas: 1
  selector:
      app: cassandra
  template:
    metadata:
      labels:
        app: cassandra
    spec:
      containers:
        - resources:
            limits:
              cpu: 0.1
              memory: 256M
          env:
            - name: MAX_HEAP_SIZE
              value: 512M
            - name: HEAP_NEWSIZE
              value: 100M
            - name: POD_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
          image: ishangulhane/cassandra
          name: cassandra
          ports:
            - containerPort: 9042
              name: cql
            - containerPort: 9160
              name: thrift
          volumeMounts:
            - mountPath: /var/lib/cassandra/data
              name: data
      volumes:
        - name: data
          emptyDir: {}
```
The Replication Controller is the one responsible for creating or deleting pods to ensure the number of Pods match its defined number in "replicas". The Pods' template are defined inside the Replication Controller. You can set how much resources will be used for each pod inside the template and limit the resources they can use.  You can create a Replication Controller using the provided yaml file with 1 replica:
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

To increase the number of Pods, you can scale the Replication Controller as many as the available resources can acccomodate. Proceed to the next step.

# 4. Scale the Replication Controller

To scale the Replication Controller, use this command:
```bash
$ kubectl scale rc cassandra --replicas=2
replicationcontroller "cassandra" scaled
```
After scaling, you should see that your desired number has increased.
```bash
$ kubectl get rc
NAME        DESIRED   CURRENT   READY     AGE
cassandra   2         2         2         3m
```
You can view the list of the Pods again to confirm that your Pods are up and running.
```bash
$ kubectl get pods -o wide
NAME              READY     STATUS    RESTARTS   AGE       IP              NODE
cassandra-1lt0j   1/1       Running   0          3m        172.xxx.xxx.xxx   169.xxx.xxx.xxx
cassandra-vsqx4   1/1       Running   0          17s       172.xxx.xxx.xxx   169.xxx.xxx.xxx
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
  - ip: 172.30.191.208
    nodeName: 169.47.232.162
    targetRef:
      kind: Pod
      name: cassandra-xp2jx
      namespace: default
      resourceVersion: "10583"
      uid: 4ee1d4e2-09b9-11e7-b645-daaa1d04f9b2
  - ip: 172.30.191.209
    nodeName: 169.47.232.162
    targetRef:
      kind: Pod
      name: cassandra-gs64p
      namespace: default
      resourceVersion: "10589"
      uid: 4ee2025b-09b9-11e7-b645-daaa1d04f9b2
  ports:
  - port: 9042
    protocol: TCP
```
# 5. Using CQL
> **Note:** It can take around 5-10 minutes for the Cassandra database to finish its setup. You may encounter an error if you did the following commands before the setup is complete.

You can check if the Cassandra in the Pod is up and running by using this command:
**Substitute the Pod name to the one you have**
```bash
$ kubectl exec cassandra-xxxxx -- nodetool status
Datacenter: DC1
===============
Status=Up/Down
|/ State=Normal/Leaving/Joining/Moving
--  Address          Load       Tokens       Owns (effective)  Host ID                               Rack
UN  172.xxx.xxx.xxx  168.59 KB  256          100.0%            b3386112-deef-4fef-8d31-691d89a78e0e  Kubernetes Cluster
```



You can access the cassandra container using the following command:

```bash
$ kubectl exec -it cassandra-xxxxx /bin/bash
root@cassandra-xxxxx:/# ls
bin  boot  dev	docker-entrypoint.sh  etc  home  initial-seed.cql  lib	lib64  media  mnt  opt	proc  root  run  sbin  srv  sys  tmp  usr  var
```

Now run the sample .cql file to create and update employee table on cassandra keyspace using the following commands:
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