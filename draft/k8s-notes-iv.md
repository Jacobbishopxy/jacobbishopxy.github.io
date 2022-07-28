# K8s 笔记四

## 工作负载

工作负载即运行在 k8s 上的应用程序。无论工作负载是单组件工作或是多组件共同工作，在 k8s 中运行的都是一系列 pods。一个 `Pod` 代表着在集群中一系列运行容器的集合。

k8s 的 pods 有定义好的生命周期。例如，一个运行在集群中的 pod 所在的节点出现致命错误时，所有该节点上的 Pods 的状态都会变成失败。k8s 将这类失败视为最终状态：即使改节点恢复正常运行，用户还是需要创建新的 Pod 用以恢复应用。

不过为了使用的便利性，用户不需要直接管理每个 `Pod`。相反的，用户可以使用*工作负载资源*来管理一系列的 pods。这类资源配置控制器可以确保正确数量以及正确类型的 pod 运行，使得匹配用户指定的状态。

k8s 提供若干内置的工作负载资源：

- `Deployment` 与 `ReplicaSet`（替换遗留资源 ReplicationController）。在集群中 `Deployment` 非常适合管理无状态应用的工作负载，在 `Deployment` 中的任何 `Pod` 都是可交替的并且需要时可以被替换。

- `StatefulSet` 以某种方式允许一个或多个关联的 Pods 追踪状态。例如，如果工作负载持久化的记录数据，用户可以允许一个 `StatefulSet` 用以匹配 `Pod` 与 `PersistentVolume`。在 `StatefulSet` 中各个 `Pods` 上运行的代码可以复制数据到统一 `StatefulSet` 中的其它 `Pod` 中以提高整体的服务可靠性。

- `DaemonSet` 定义 `Pods` 提供节点本地的设备。这可能是集群中的基础，例如一个网络帮助工具，或是插件的一部分。每添加一个节点至集群，如果节点与某 `DaemonSet` 的规约匹配，则控制面会为该 `DaemonSet` 调度一个 `Pod` 至新的节点。

- `Job` 与 `CronJob`。定义一些一直运行到结束并停止的任务。`Job` 用来表达的是一次性任务，而 `CronJob` 会根据其时间规则反复运行。

### Pod

在 k8s 中，*Pods*是可以创建与管理的最小可部署计算单元。

一个*Pod*是一组单个或多个的容器，它们共享存储与网络资源，以及指定的运行容器的方法。一个 Pod 总是并置 co-located 与共同调度 co-scheduled 的，并且运行在共享的上下文中。一个 Pod 是一个“逻辑主机”的模型：它包含了一个或多个相对紧密耦合的应用容器。在非云环境中，相同的物理机或虚拟机上运行的应用类似于在同一逻辑主机上运行的云应用。

除了应用容器，Pod 还可以包含在 Pod 启动期间运行的初始容器 init containers。也可以在集群中支持临时容器 ephemeral containers 时注入调试用的临时性容器。

<!-- #### Pod 生命周期
#### 初始化容器
#### 干扰
#### 临时容器
#### Downward API -->

#### 什么是 Pod

> **注意：**除了 Docker，k8s 支持很多的容器运行时，而 Docker 是最为熟知的运行时，使用 Docker 的术语描述 Pod 会很有帮助。

一个 Pod 共享的上下文就是一系列的 Linux 命名空间，控制组 cgroups，以及其它隔离技术。在一个 Pod 的上下文中，可能会对应用程序更进一步的子隔离。

根据 Docker 的概念，一个 Pod 类似于一组共享了命名空间与文件系统卷的 Docker 容器。

#### 使用 Pods

以下是一个由一个运行的镜像 `nginx:1.14.2` 构成的 Pod 例子：

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
spec:
  containers:
    - name: nginx
      image: nginx:1.14.2
      ports:
        - containerPort: 80
```

通过一下命令来创建上述的 Pod：

```sh
kubectl apply -f https://k8s.io/examples/pods/simple-pod.yaml
```

Pods 通常不会直接被创建而是通过工作负载资源来创建。

##### 工作负载资源管理 pods

##### Pods 如何管理多个容器

#### 通过 Pods 工作

##### Pods 与控制器

##### Pod 模板

#### Pod 更新与替换

#### 资源共享与通讯

#### 容器的特权模式

#### 静态 Pod

#### 容器探针

### 工作负载资源

<!-- #### Deployments
#### ReplicaSet
#### StatefulSets
#### DaemonSet
#### Jobs
#### 已完成 Jobs 的自动清理
#### CronJob
#### ReplicationController -->
