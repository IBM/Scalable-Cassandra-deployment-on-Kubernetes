[![构建状态](https://travis-ci.org/IBM/Scalable-Cassandra-deployment-on-Kubernetes.svg?branch=master)](https://travis-ci.org/IBM/Scalable-Cassandra-deployment-on-Kubernetes)

# Kubernetes 集群上的可扩展多节点 Cassandra 部署

*阅读本文的其他语言版本：[English](README.md)。*

本项目将演示如何将一个多节点可扩展 Cassandra 集群部署在 Kubernetes 上。Apache Cassandra 是一个可大规模扩展的开源 NoSQL 数据库。Cassandra 非常适合管理跨多个数据中心和云的大量结构化、半结构化和非结构化数据。

利用 Kubernetes 概念，比如 [PersistentVolume](https://kubernetes.io/docs/concepts/storage/persistent-volumes/) 和 [StatefulSet](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)，我们可以提供一种具有容灾能力的 Cassandra 安装，并确信它的数据（状态）是安全的。

我们还对 Cassandra 使用了一个[“headless” service](https://kubernetes.io/docs/concepts/services-networking/service/#headless-services)。这样，我们就可以为应用程序提供一种通过 [KubeDNS](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/) 访问它的方式，而且不会将它暴露给外部世界。要从您的开发人员工作站访问它，您可以对任何 Cassandra Pod 使用 `kubectl exec` 命令。如果您确实希望将应用程序连接到它，那么您可以在配置您的应用程序时使用 KubeDNS 值 `cassandra.default.svc.cluster.local`。

![kube-cassandra](images/kube-cassandra-code.png)

## 使用的 Kubernetes 概念

* [Kubenetes Pods](https://kubernetes.io/docs/user-guide/pods)
* [Kubenetes 服务](https://kubernetes.io/docs/user-guide/services)
* [Kubernets StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)

## 包含的组件
* [Kubernetes 集群](https://console.ng.bluemix.net/docs/containers/cs_ov.html#cs_ov)
* [IBM Cloud Container 服务](https://console.ng.bluemix.net/catalog/?taxonomyNavigation=apps&category=containers)
* [IBM Cloud Private](https://www.ibm.com/cloud-computing/products/ibm-cloud-private/)
* [Cassandra](http://cassandra.apache.org/)

## 入门

要遵循本指南进行操作，您需要一个 Kubernetes 集群。如果无法访问现有的 Kubernetes 集群，请按照操作说明（在链接中）提供以下组件之一：

* [Minikube](https://kubernetes.io/docs/getting-started-guides/minikube)，在您的工作站上
* [IBM Cloud Container 服务](https://github.com/IBM/container-journey-template#container-journey-template---creating-a-kubernetes-cluster)，部署在一个 IBM 管理的集群中（免费的小集群）
* [IBM Cloud Private - 社区版](https://github.com/IBM/deploy-ibm-cloud-private/blob/master/README.md)，用于获得一个自主管理的 Kubernetes 集群（在 Vagrant、Softlayer 或 OpenStack 中）

_这里的代码会定期使用 Travis CI针对[来自 Cloud Container 服务的 Kubernetes 集群](https://console.ng.bluemix.net/docs/containers/cs_ov.html#cs_ov) 进行测试。_

安装 Kubernetes（或设置对它的访问权）后，通过运行以下命令并确认获得了客户端和服务器的版本响应，确保您能访问它：

```shell
$ kubectl version
Client Version: version.Info{Major:"1", Minor:"7", GitVersion:"v1.7.5", GitCommit:"17d7182a7ccbb167074be7a87f0a68bd00d58d97", GitTreeState:"clean", BuildDate:"2017-08-31T09:14:02Z", GoVersion:"go1.8.3", Compiler:"gc", Platform:"linux/amd64"}
Server Version: version.Info{Major:"1", Minor:"7", GitVersion:"v1.7.5", GitCommit:"17d7182a7ccbb167074be7a87f0a68bd00d58d97", GitTreeState:"clean", BuildDate:"2017-09-18T20:30:29Z", GoVersion:"go1.8.3", Compiler:"gc", Platform:"linux/amd64"}
```

## 创建一个 Cassandra 服务来实现 Cassandra 集群组建和发现

### 1.创建一个 Cassandra Headless Service

为了使我们能对 Cassandra 种子节点（我们很快将部署它）执行简单的发现操作，我们可以创建一个”Headless” service。  为此，我们为 [cassandra-service.yaml](cassandra-service.yaml) 中的 **clusterIP** 指定 **none**。这个”Headless” service允许 Pod 使用 KubeDNS发现 Cassandra 种子的 IP 地址。

您可以使用 [cassandra-service.yaml](cassandra-service.yaml) 文件创建这个”Headless” service：

```shell
$ kubectl create -f cassandra-service.yaml
service "cassandra" created
$ kubectl get svc cassandra
NAME        CLUSTER-IP   EXTERNAL-IP   PORT(S)    AGE
cassandra   None         <none>        9042/TCP   10s
```

部署到 Kubernetes 的大部分应用程序都应该是云原生的，而且依靠外部资源来存储其数据（或状态）。但是，因为 Cassandra 是一个数据库，所以我们可以使用Stateful Sets和Persistent Volume来确保数据库的容灾能力。

### 2.创建本地卷

要创建持久 Cassandra 节点，需要配备Persistent Volume (PV)。可通过两种方式配备PV：**动态和静态**。

出于简单性和兼容性，我们将使用**静态**配备功能，使用所提供的 yaml 文件手动创建卷。

_备注：您将需要与 Cassandra 节点数量相同的持久卷。如果您希望有 3 个 Cassandra 节点，则需要创建 3 个PV。_

提供的 [local-volumes.yaml](local-volumes.yaml) 文件已定义了 **3** 个持久卷。如果您希望拥有 3 个以上的 Cassandra 节点，可以更新该文件来添加更多卷。创建这些卷：

```shell
$ kubectl create -f local-volumes.yaml
$ kubectl get pv   
NAME               CAPACITY   ACCESSMODES   RECLAIMPOLICY   STATUS      CLAIM     STORAGECLASS   REASON    AGE
cassandra-data-1   1Gi        RWO           Recycle         Available                                      7s
cassandra-data-2   1Gi        RWO           Recycle         Available                                      7s
cassandra-data-3   1Gi        RWO           Recycle         Available                                      7s
```

### 3.创建一个 StatefulSet

[StatefulSet](cassandra-statefulset.yaml) 负责创建 Pod。它提供有序部署、有序终止和唯一网络名称。运行以下命令来启动一个 Cassandra 服务器：

```shell
$ kubectl create -f cassandra-statefulset.yaml
```
### 4.验证 StatefulSet

可以使用以下命令检查您的 StatefulSet 是否已部署。

```shell
$ kubectl get statefulsets
NAME        DESIRED   CURRENT   AGE
cassandra   1         1         2h
```

如果查看 Pod 列表，您会看到 1 个 Pod 正在运行。您的 Pod 名称应该是 cassandra-0，后续 Pod 将按照序数编号（*cassandra-1、cassandra-2、……*）进行命名使用此命令查看 StatefulSet 创建的 Pod：

```shell
$ kubectl get pods -o wide
NAME          READY     STATUS    RESTARTS   AGE       IP              NODE
cassandra-0   1/1       Running   0          1m        172.xxx.xxx.xxx   169.xxx.xxx.xxx
```

要检查 Cassandra 节点是否启动，可以执行 **nodetool status：**

```shell
$ kubectl exec -ti cassandra-0 -- nodetool status
Datacenter: DC1
===============
Status=Up/Down
|/ State=Normal/Leaving/Joining/Moving
--  Address          Load       Tokens       Owns (effective)   Host ID                               Rack
UN  172.xxx.xxx.xxx  109.28 KB  256          100.0%             6402e90d-7995-4ee1-bb9c-36097eb2c9ec  Rack1
```
### 5.扩展 StatefulSet

要扩大或缩小 StatefulSet 的大小，可以使用 scale 命令：

```shell
$ kubectl scale --replicas=3 statefulset/cassandra
```

等待一两分钟，检查命令是否有效：

```shell
$ kubectl get statefulsets
NAME        DESIRED   CURRENT   AGE
cassandra   3         3         2h
```

如果观察 Cassandra Pod 的部署，就会发现它们是按顺序创建的。

可以再次查看 Pod 列表，确认您的 Pod 在正常运行。

```shell
$ kubectl get pods -o wide
NAME          READY     STATUS    RESTARTS   AGE       IP                NODE
cassandra-0   1/1       Running   0          13m       172.xxx.xxx.xxx   169.xxx.xxx.xxx
cassandra-1   1/1       Running   0          38m       172.xxx.xxx.xxx   169.xxx.xxx.xxx
cassandra-2   1/1       Running   0          38m       172.xxx.xxx.xxx   169.xxx.xxx.xxx
```

可以执行 **nodetool status** 来检查是否有其他 Cassandra 节点加入并形成了一个 Cassandra 集群。

_**备注：**Cassandra 数据库完成设置可能会花大约 5 分钟的时间。_

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

_需要等到节点的状态变为 Up and Normal (UN)，才能执行后续步骤中的命令。_

### 6.使用 CQL

可以使用以下命令访问 Cassandra 容器：

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

## 故障排除

* 如果您的 Cassandra 实例未正确运行，可以使用以下命令来检查日志
	* `kubectl logs <your-pod-name>`
* 要清理/删除持久卷上的数据，可以使用以下命令来删除 PVC
	* `kubectl delete pvc -l app=cassandra`
* 如果您的 Cassandra 节点未加入，可以删除您的控制器/statefulset，然后删除您的 Cassandra 服务。
	* 如果您创建了 Cassandra StatefulSet，则使用 `kubectl delete statefulset cassandra`
	* `kubectl delete svc cassandra`
* 删除所有信息：
	* `kubectl delete statefulset,pvc,pv,svc -l app=cassandra`

## 参考资料
* 这个 Cassandra 示例基于 Kubernete 的[使用 Kubernetes 的云原生 Cassandra 部署](https://github.com/kubernetes/kubernetes/tree/master/examples/storage/cassandra)。

# 隐私声明

可以配置包含这个包的样本 Kubernetes Yaml 文件来跟踪对 [IBM Cloud](https://www.bluemix.net/) 和其他 Kubernetes 平台的部署。每次部署时，都会将以下信息发送到 [Deployment Tracker](https://github.com/IBM/metrics-collector-service) 服务：

* Kubernetes 集群提供者（`IBM Cloud、Minikube 等`）
* Kubernetes 机器 ID
* Kubernetes 集群 ID（仅来自 IBM Cloud 的集群）
* Kubernetes 客户 ID（仅来自 IBM Cloud 的集群）
* 这个 Kubernetes 作业中的环境变量。

此数据收集自样本应用程序的 yaml 文件中的 Kubernetes 作业。IBM 使用此数据来跟踪与将样本应用程序部署到 IBM Cloud 相关的指标，以度量我们的示例的实用性，让我们可以持续改进为您提供的内容。仅跟踪包含对 Deployment Tracker 服务执行 ping 操作的代码的样本应用程序的部署过程。

## 禁用部署跟踪

请注释掉/删除 'cassandra-service.yaml' 文件末尾的 Metric Kubernetes Job 部分。
