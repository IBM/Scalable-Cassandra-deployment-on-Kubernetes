[![Build Status](https://travis-ci.org/IBM/Scalable-Cassandra-deployment-on-Kubernetes.svg?branch=master)](https://travis-ci.org/IBM/Scalable-Cassandra-deployment-on-Kubernetes)
# Implementação de Cassandra escalável com vários nós em cluster Kubernetes

*Ler em outros idiomas: [한국어](README-ko.md).*

Este projeto demonstra a implementação de um cluster Cassandra escalável com vários nós no Kubernetes. O Apache Cassandra é um banco de dados NoSQL de software livre extremamente escalável. Ele é perfeito para gerenciar grandes quantias de dados estruturados, semiestruturados e não estruturados em vários datacenters e na cloud.

Nesta jornada, mostramos uma implementação de Cassandra nativa na cloud no Kubernetes. O Cassandra entende que está sendo executado dentro de um gerenciador de clusters e usa essa infraestrutura de gerenciamento de clusters para ajudar a implementar o aplicativo.

Utilizando conceitos do Kubernetes como Replication Controller e StatefulSets, oferecemos instruções passo a passo para implementar clusters Cassandra não persistentes ou persistentes no Bluemix Container Service com o cluster Kubernetes

![kube-cassandra](images/kube-cassandra-code.png)

## Conceitos do Kubernetes usados
- [Pods do Kubernetes](https://kubernetes.io/docs/user-guide/pods)
- [Serviços do Kubernetes](https://kubernetes.io/docs/user-guide/services)
- [Kubernetes Replication Controller](https://kubernetes.io/docs/user-guide/replication-controller/)
- [Kubernets StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)
## Componentes inclusos
- [Clusters Kubernetes](https://console.ng.bluemix.net/docs/containers/cs_ov.html#cs_ov)
- [Bluemix Container Service](https://console.ng.bluemix.net/catalog/?taxonomyNavigation=apps&amp;category=containers)
- [Bluemix DevOps Toolchain Service](https://console.ng.bluemix.net/catalog/services/continuous-delivery)
- [Cassandra](http://cassandra.apache.org/)
## Pré-requisito
Criar um cluster Kubernetes com [Minikube](https://kubernetes.io/docs/getting-started-guides/minikube) para testes locais ou com [IBM Bluemix Container Service](https://github.com/IBM/container-journey-template) para implementação na cloud. O código é testado regularmente com relação ao [Cluster Kubernetes do Bluemix Container Service](https://console.ng.bluemix.net/docs/containers/cs_ov.html#cs_ov) usando Travis.

## Implementar no Cluster Kubernetes a partir do Bluemix
Se quiser implementar diretamente no Bluemix, clique no botão 'Deploy to Bluemix' abaixo para criar uma cadeia de ferramentas de serviço do Bluemix DevOps e um canal para implementação da amostra ou avance para [Etapas](#steps)

> Você precisará criar um cluster Kubernetes, em primeiro lugar, e verificar se foi totalmente implementado na conta do Bluemix.

[![Create Toolchain](https://github.com/IBM/container-journey-template/blob/master/images/button.png)](https://console.ng.bluemix.net/devops/setup/deploy/)

Siga as [instruções da cadeia de ferramentas](https://github.com/IBM/container-journey-template/blob/master/Toolchain_Instructions.md) para concluir a cadeia de ferramentas e o canal. O cluster Cassandra não será exposto no IP público do cluster Kubernetes. Ainda será possível acessar exportando a configuração do cluster Kubernetes com `bx cs cluster-config <your-cluster-name>` e realizando a [Etapa 5](#5-using-cql) ou simplesmente verificar o status `kubectl exec <POD-NAME> -- nodetool status`

## Etapas

### Criar um serviço do Cassandra para formação e descoberta de cluster do Cassandra
1. [Criar um serviço sem interface com o usuário do Cassandra](#1-create-a-cassandra-headless-service)
### Usar o Replication Controller para criar um cluster Cassandra não persistente
2. [Criar um Replication Controller](#2-create-a-replication-controller)
3. [Validar o Replication Controller](#3-validate-the-replication-controller)
4. [Ajustar a escala do Replication Controller](#4-scale-the-replication-controller)
5. [Usar a Cassandra Query Language (CQL)](#5-using-cql)
### Usar StatefulSets para criar um cluster Cassandra persistente
6. [Criar volumes locais](#6-create-local-volumes)
7. [Criar um StatefulSet](#7-create-a-statefulset)
8. [Validar o StatefulSet](#8-validate-the-statefulset)
9. [Ajustar a escala do StatefulSet](#9-scale-the-statefulset)
10. [Usar a Cassandra Query Language(CQL)](#10-using-cql)

#### [Resolução de Problemas](#troubleshooting-1)
# 1. Criar um serviço sem interface com o usuário do Cassandra
Neste aplicativo de amostra, você não precisa de balanceamento de cargas nem de um único IP de serviço. Neste caso, é possível criar um serviço "sem interface com o usuário" especificando **none** para **clusterIP**.

Precisaremos do serviço sem interface com o usuário para os pods para descobrir o endereço IP do valor inicial do Cassandra. Esta é a descrição do serviço para o serviço sem interface com o usuário:
```yaml
apiVersion: v1
kind: Service metadata:
  labels:
    app: cassandra
    name: cassandra
    spec:
      clusterIP: None ports: - port: 9042
      selector:
        app: cassandra
```

Para criar o serviço sem interface com o usuário, utilize o arquivo yaml fornecido:

  ```bash
  $ kubectl create -f cassandra-service.yaml service "cassandra" created
  ```

  Se quiser criar um cluster Cassandra persistente usando StatefulSets, avance para a [Etapa 6](#6-create-local-volumes)

# 2. Criar um Replication Controller
O Replication Controller é responsável por criar ou excluir pods para garantir que o número de pods corresponderá ao número definido em "réplicas". O modelo dos pods é definido dentro do Replication Controller. É possível definir quantos recursos serão usados para cada pod dentro do modelo, assim como limitar os recursos que podem ser utilizados. Esta é a descrição do Replication Controller:

```yaml
  apiVersion: v1 kind: Replication Controller
  metadata: name: cassandra
  # The labels will be applied automatically
  # from the labels in the pod template, if not set
  # labels:
  # app: cassandra spec: replicas: 1
  # The selector will be applied automatically
  # from the labels in the pod template, if not set.
  # selector:
  # app: cassandra template: metadata: labels: app: cassandra spec: containers: - env: - name: CASSANDRA_SEED_DISCOVERY value: cassandra
  # CASSANDRA_SEED_DISCOVERY should match the name of the service in cassandra-service.yaml - name: CASSANDRA_CLUSTER_NAME value: Cassandra - name: CASSANDRA_DC value: DC1 - name: CASSANDRA_RACK value: Rack1 - name: CASSANDRA_ENDPOINT_SNITCH value: GossipingPropertyFileSnitch image: docker.io/anthonyamanse/cassandra-demo:7.0 name: cassandra ports: - containerPort: 7000 name: intra-node - containerPort: 7001 name: tls-intra-node - containerPort: 7199 name: jmx - containerPort: 9042 name: cql volumeMounts: - mountPath: /var/lib/cassandra/data name: data volumes: - name: data emptyDir: {}
```

Para criar um Replication Controller, use o arquivo yaml fornecido com uma réplica:

```bash
$ kubectl create -f cassandra-controller.yaml replication controller "cassandra" created
```
# 3. Validar o Replication Controller
É possível visualizar uma lista de Replication Controllers usando este comando:
```bash
$ kubectl get rc NAME DESIRED CURRENT READY AGE cassandra 1 1 1 1m
```
Se você visualizar a lista dos pods, deverá ver um pod em execução. Utilize este comando para visualizar os pods criados pelo Replication Controller:
```bash
$ kubectl get pods -o wide NAME READY STATUS RESTARTS AGE IP NODE cassandra-xxxxx 1/1 Running 0 1m 172.xxx.xxx.xxx 169.xxx.xxx.xxx
```
Para verificar se o nó do Cassandra está funcionando, execute um **nodetool status:**
> Talvez você não consiga executar esse comando por algum tempo se o pod ainda não tiver criado o contêiner ou se a configuração da instância do Cassandra não tiver terminado.
```bash
$ kubectl exec -ti cassandra-xxxxx -- nodetool status
Datacenter: DC1
===============
Status=Up/Down |/ State=Normal/Leaving/Joining/Moving -- Address Load
Tokens Owns (effective)
Host ID Rack UN 172.xxx.xxx.xxx 109.28 KB 256 100.0% 6402e90d-7995-4ee1-bb9c-36097eb2c9ec Rack1
 ```
  Para aumentar o número de pods, é possível aumentar a escala do Replication Controller da forma permitida pelos recursos disponíveis. Avance para a próxima etapa.

# 4. Ajustar a escala do Replication Controller
Para ajustar a escala do Replication Controller, use este comando:
```bash
$ kubectl scale rc cassandra --replicas=4 replication controller "cassandra" scaled
```
Após o ajuste de escala, você deve ver que o número desejado aumentou.
```bash
 $ kubectl get rc NAME DESIRED CURRENT READY AGE cassandra 4 4 4 3m
```
Você pode visualizar a lista de pods novamente para confirmar se seus pods estão funcionando.


```bash
$ kubectl get pods -o wide NAME READY STATUS RESTARTS AGE IP NODE cassandra-1lt0j 1/1 Running 0 13m 172.xxx.xxx.xxx 169.xxx.xxx.xxx cassandra-vsqx4 1/1 Running 0 38m 172.xxx.xxx.xxx 169.xxx.xxx.xxx cassandra-jjx52 1/1 Running 0 38m 172.xxx.xxx.xxx 169.xxx.xxx.xxx cassandra-wzlxl 1/1 Running 0 38m 172.xxx.xxx.xxx 169.xxx.xxx.xxx
```
 Para verificar se os pods estão visíveis para o serviço, use a consulta de terminais de serviço a seguir:

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
     resourceVersion: "10591" selfLink: /api/v1/namespaces/default/endpoints/cassandra
     uid: 03e992ca-09b9-11e7-b645-daaa1d04f9b2
     subsets: - addresses: - ip: 172.xxx.xxx.xxx
     nodeName: 169.xxx.xxx.xxx targetRef: kind: Pod name: cassandra-xp2jx
     namespace: default resourceVersion: "10583" uid: 4ee1d4e2-09b9-11e7-b645-daaa1d04f9b2 -
     ip: 172.xxx.xxx.xxx
     nodeName: 169.xxx.xxx.xxx
     targetRef:
       kind:
        Pod name: cassandra-gs64p
        namespace: default
        resourceVersion: "10589"
        uid: 4ee2025b-09b9-11e7-b645-daaa1d04f9b2 -
        ip: 172.xxx.xxx.xxx
        nodeName: 169.xxx.xxx.xxx
        targetRef:
          kind:
            Pod name: cassandra-g5wh8 n
            amespace: default
            resourceVersion: "109410" uid: a39ab3ce-0b5a-11e7-b26d-665c3f9e8d67 -
            ip: 172.xxx.xxx.xxx
            nodeName: 169.xxx.xxx.xxx
            targetRef:
              kind:
                Pod name: cassandra-gf37p
                namespace: default resourceVersion: "109418"
                uid: a39abcb9-0b5a-11e7-b26d-665c3f9e8d67
                ports: - port: 9042
                protocol: TCP
  ```
  É possível realizar um **nodetool status** para verificar se os outros nós do Cassandra se uniram e formaram um cluster Cassandra. **Substitua o nome do pod pelo que você tem:**
 ```bash
   $ kubectl exec -ti cassandra-xxxxx -- nodetool
   status Datacenter: DC1
   =============== Status=Up/Down |/ State=Normal/Leaving/Joining/Moving --
   Address           Load        Tokens    Owns (effective)      Host                                 ID Rack UN
   172.xxx.xxx.xxx   109.28 KB   256       50.0%                 6402e90d-7995-4ee1-bb9c-36097eb2c9ec Rack1 UN 172.xxx.xxx.xxx 196.04 KB 256 51.4% 62eb2a08-c621-4d9c-a7ee-ebcd3c859542                                         Rack1 UN 172.xxx.xxx.xxx 114.44 KB 256 46.2% 41e7d359-be9b-4ff1-b62f-1d04aa03a40c Rack1 UN 172.xxx.xxx.xxx 79.83 KB 256 52.4% fb1dd881-0eff-4883-88d0-91ee31ab5f57 Rack1
 ```
 # 5. Usar CQL
 > **Observação:** a configuração do banco de dados do Cassandra pode levar cerca de cinco minutos para ser concluída. Para verificar se os nós do Cassandra estão funcionando, utilize este comando:
**Substitua o nome do pod pelo que você tem**
 ```bash
  $ kubectl exec cassandra-xxxxx -- nodetool
  status Datacenter: DC1
  =============== Status=Up/Down |/ State=Normal/Leaving/Joining/Moving --
  Address                Load              Tokens Owns (effective)        Host ID                                Rack UN
  172.xxx.xxx.xxx        109.28 KB         256 50.0%                      6402e90d-7995-4ee1-bb9c-36097eb2c9ec   Rack1 UN 172.xxx.xxx.xxx   196.04 KB 256 51.4% 62eb2a08-c621-4d9c-a7ee-ebcd3c859542 Rack1 UN 172.xxx.xxx.xxx 114.44 KB 256 46.2% 41e7d359-be9b-4ff1-b62f-1d04aa03a40c Rack1 UN 172.xxx.xxx.xxx 79.83 KB 256 52.4% fb1dd881-0eff-4883-88d0-91ee31ab5f57 Rack1
  ```
> Você precisará aguardar até o status dos nós ser Up and Normal (UN) para executar os comandos nas próximas etapas. Para acessar o contêiner do Cassandra, utilize o comando a seguir:
 ```bash
    $ kubectl exec -it cassandra-xxxxx /bin/bash root@cassandra-xxxxx:/# ls bin boot dev docker-entrypoint.sh etc home initial-seed.cql lib lib64 media mnt opt proc root run sbin srv sys tmp usr var
 ```
Agora, execute o arquivo sample .cql para criar e atualizar a tabela de funcionários no espaço de teclas do Cassandra usando os comandos a seguir: &gt; O arquivo .cql precisa ser executado apenas **uma vez** em **UM** nó do Cassandra. Os outros pods também devem ter acesso à tabela de amostra criada pelo arquivo .cql.
```bash
root@cassandra-xxxxx:/# cqlsh -f initial-seed.cql root@cassandra-xxxxx:/# cqlsh Connected to Test Cluster at 127.0.0.1:9042. [cqlsh 5.0.1 | Cassandra 3.10 | CQL spec 3.4.4 | Native protocol v4] Use HELP for help. cqlsh&gt; DESCRIBE TABLES Keyspace my_cassandra_keyspace ------------------------------ employee Keyspace system_schema ---------------------- tables triggers views keyspaces dropped_columns functions aggregates indexes types columns Keyspace system_auth -------------------- resource_role_permissons_index role_permissions role_members roles Keyspace system --------------- available_ranges peers batchlog transferred_ranges batches compaction_history size_estimates hints prepared_statements sstable_activity built_views "IndexInfo" peer_events range_xfers views_builds_in_progress paxos local Keyspace system_distributed --------------------------- repair_history view_build_status parent_repair_history Keyspace system_traces ---------------------- events sessions cqlsh&gt; SELECT * FROM my_cassandra_keyspace.employee; emp_id | emp_city | emp_name | emp_phone | emp_sal --------+----------+----------+------------+--------- 1 | SF | David | 9848022338 | 50000 2 | SJC | Robin | 9848022339 | 40000 3 | Austin | Bob | 9848022330 | 45000
```
eu cluster Cassandra não persistente está pronto!! **Se quiser criar clusters Cassandra persistentes, prossiga. Antes de avançar para as próximas etapas, exclua o Cassandra Replication Controller.**
```bash
$ kubectl delete rc cassandra
```

# 6. Criar volumes locais
[Crie um serviço sem interface com o usuário do Cassandra](#1-create-a-cassandra-headless-service), caso ainda não tenha feito isso, antes de prosseguir. Para criar nós persistentes do Cassandra, precisamos fornecer volumes persistentes (persistent volumes, ou PV). Há duas maneiras de fornecer PVs: **dinâmica e estática**.

Para o fornecimento **dinâmico**, você precisará ter **StorageClasses** e um serviço de cluster Kubernetes **pago**.

Nesta jornada, utilizaremos o fornecimento **estático** para criar volumes manualmente usando os arquivos yaml fornecidos. **Você precisará ter um número de volumes persistentes igual ao número de nós do Cassandra.**

> Exemplo: Se estiver esperando quatro nós do Cassandra, precisará criar quatro volumes persistentes O arquivo yaml fornecido já tem **4** volumes persistentes definidos. Configure-os para incluir mais caso esteja esperando ter mais de quatro nós do Cassandra.

```bash
$ kubectl create -f local-volumes.yaml
```
Você utilizará o mesmo serviço que foi criado antes. # 7. Criar um StatefulSet &gt; Confira se excluiu o Replication Controller caso ele ainda esteja em execução. `kubectl delete rc cassandra` O StatefulSet é responsável pela criação dos pods. Ele tem os recursos de implementação ordenada, terminação ordenada e nomes exclusivos de rede. Você começará com um único nó do Cassandra usando StatefulSet. Execute o comando a seguir.

```bash
$ kubectl create -f cassandra-statefulset.yaml
```
 # 8. Validar o StatefulSet

 Para verificar se o StatefulSet foi implementado, use o comando abaixo.

 ```bash
  $ kubectl get statefulsets NAME DESIRED CURRENT AGE cassandra 1 1 2h
  ```
 Se você visualizar a lista dos pods, deverá ver um pod em execução. O nome do pod deve ser cassandra-0; os próximos pods seguiriam o número ordinal (*cassandra-1, cassandra-2,..*) Utilize este comando para visualizar os pods criados pelo StatefulSet:
```bash
  $ kubectl get pods -o wide NAME READY STATUS RESTARTS AGE IP NODE cassandra-0 1/1 Running 0 1m 172.xxx.xxx.xxx 169.xxx.xxx.xxx
```
Para verificar se o nó do Cassandra está funcionando, realize um **nodetool status:**
```bash
      $ kubectl exec -ti cassandra-0 -- nodetool status Datacenter: DC1 =============== Status=Up/Down |/ State=Normal/Leaving/Joining/Moving -- Address Load Tokens Owns (effective) Host ID Rack UN 172.xxx.xxx.xxx 109.28 KB 256 100.0% 6402e90d-7995-4ee1-bb9c-36097eb2c9ec Rack1
```

# 9. Ajustar a escala do StatefulSet
Para aumentar ou diminuir o tamanho do StatefulSet, utilize este comando:
 ```bash
$ kubectl edit statefulset cassandra
 ```
Você deve ser redirecionado para um editor no seu terminal. Você precisa editar a linha que diz `replicas: 1` e alterá-la para `replicas: 4` Salve-a; agora, o StatefulSet deve ter quatro pods Após o ajuste de escala, você deve ver que o número desejado aumentou.
```bash
$ kubectl get statefulsets NAME DESIRED CURRENT AGE cassandra 4 4 2h
```
Se você assistir à implementação de pods do Cassandra, verá que devem ser criados sequencialmente. Você pode visualizar a lista de pods novamente para confirmar se seus pods estão funcionando.
```bash
$ kubectl get pods -o wide NAME READY STATUS RESTARTS AGE IP NODE cassandra-0 1/1 Running 0 13m 172.xxx.xxx.xxx 169.xxx.xxx.xxx cassandra-1 1/1 Running 0 38m 172.xxx.xxx.xxx 169.xxx.xxx.xxx cassandra-2 1/1 Running 0 38m 172.xxx.xxx.xxx 169.xxx.xxx.xxx cassandra-3 1/1 Running 0 38m 172.xxx.xxx.xxx 169.xxx.xxx.xxx
```
É possível realizar um **nodetool status** para verificar se os outros nós do Cassandra se uniram e formaram um cluster Cassandra.
```bash
$ kubectl exec -ti cassandra-0 -- nodetool status Datacenter: DC1 =============== Status=Up/Down |/ State=Normal/Leaving/Joining/Moving -- Address Load Tokens Owns (effective) Host ID Rack UN 172.xxx.xxx.xxx 109.28 KB 256 50.0% 6402e90d-7995-4ee1-bb9c-36097eb2c9ec Rack1 UN 172.xxx.xxx.xxx 196.04 KB 256 51.4% 62eb2a08-c621-4d9c-a7ee-ebcd3c859542 Rack1 UN 172.xxx.xxx.xxx 114.44 KB 256 46.2% 41e7d359-be9b-4ff1-b62f-1d04aa03a40c Rack1 UN 172.xxx.xxx.xxx 79.83 KB 256 52.4% fb1dd881-0eff-4883-88d0-91ee31ab5f57 Rack1
```
# 10. Usar a CQL
É possível realizar a [Etapa 5](#5-using-cql) novamente para usar CQL no cluster Cassandra implementado com StatefulSet.

## Resolução de Problemas
* Se a instância do Cassandra não estiver funcionando adequadamente, você poderá verificar os logs usando
 * `kubectl logs <your-pod-name>`
* Para remover/excluir dados dos volumes persistentes, exclua seus PVCs usando
 * `kubectl delete pvc -l app=cassandra`
* Caso os nós do Cassandra não estejam se unindo, exclua o controlador/statefulset e, em seguida, exclua o serviço do Cassandra.
 * `kubectl delete rc cassandra` se criou o Cassandra Replication Controller
 * `kubectl delete statefulset cassandra` se criou o Cassandra StatefulSet
 * `kubectl delete svc cassandra`
* Para excluir tudo:
 * `kubectl delete rc,statefulset,pvc,svc -l app=cassnadra` * `kubectl delete pv -l type=local`
## Referências
* Este exemplo do Cassandra baseia-se em [Implementações do Cassandra nativas na cloud usando Kubernetes](https://github.com/kubernetes/kubernetes/tree/master/examples/storage/cassandra) do Kubernetes.
## Licença
[Apache 2.0](http://www.apache.org/licenses/LICENSE-2.0)
