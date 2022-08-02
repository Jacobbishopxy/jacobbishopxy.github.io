+++
title="K8s 笔记 (IV) 上"
description="工作负载（Pod）"
date=2022-08-01

[taxonomies]
categories = ["Doc"]
tags = ["k8s"]

[extra]
toc = true
+++

## 简介

工作负载即运行在 k8s 上的应用程序。无论工作负载是单组件工作或是多组件共同工作，在 k8s 中运行的都是一系列 pods。一个 `Pod` 代表着在集群中一系列运行容器的集合。

k8s 的 pods 有定义好的生命周期。例如，一个运行在集群中的 pod 所在的节点出现致命错误时，所有该节点上的 Pods 的状态都会变成失败。k8s 将这类失败视为最终状态：即使改节点恢复正常运行，用户还是需要创建新的 Pod 用以恢复应用。

不过为了使用的便利性，用户不需要直接管理每个 `Pod`。相反的，用户可以使用*负载资源*来管理一系列的 pods。这类资源配置控制器可以确保正确数量以及正确类型的 pod 运行，使得匹配用户指定的状态。

k8s 提供若干内置的工作负载资源：

- `Deployment` 与 `ReplicaSet`（替换遗留资源 ReplicationController）。在集群中 `Deployment` 非常适合管理无状态应用的工作负载，在 `Deployment` 中的任何 `Pod` 都是可交替的并且需要时可以被替换。

- `StatefulSet` 以某种方式允许一个或多个关联的 Pods 追踪状态。例如，如果工作负载持久化的记录数据，用户可以允许一个 `StatefulSet` 用以匹配 `Pod` 与 `PersistentVolume`。在 `StatefulSet` 中各个 `Pods` 上运行的代码可以复制数据到统一 `StatefulSet` 中的其它 `Pod` 中以提高整体的服务可靠性。

- `DaemonSet` 定义 `Pods` 提供节点本地的设备。这可能是集群中的基础，例如一个网络帮助工具，或是插件的一部分。每添加一个节点至集群，如果节点与某 `DaemonSet` 的规约匹配，则控制面会为该 `DaemonSet` 调度一个 `Pod` 至新的节点。

- `Job` 与 `CronJob`。定义一些一直运行到结束并停止的任务。`Job` 用来表达的是一次性任务，而 `CronJob` 会根据其时间规则反复运行。

## Pod

在 k8s 中，*Pods*是可以创建与管理的最小可部署计算单元。

一个*Pod*是一组单个或多个的容器，它们共享存储与网络资源，以及指定的运行容器的方法。一个 Pod 总是并置 co-located 与共同调度 co-scheduled 的，并且运行在共享的上下文中。一个 Pod 是一个“逻辑主机”的模型：它包含了一个或多个相对紧密耦合的应用容器。在非云环境中，相同的物理机或虚拟机上运行的应用类似于在同一逻辑主机上运行的云应用。

除了应用容器，Pod 还可以包含在 Pod 启动期间运行的初始容器 init containers。也可以在集群中支持临时容器 ephemeral containers 时注入调试用的临时性容器。

### 什么是 Pod

> **注意：**
> 除了 Docker，k8s 支持很多的容器运行时，而 Docker 是最为熟知的运行时，使用 Docker 的术语描述 Pod 会很有帮助。

一个 Pod 共享的上下文就是一系列的 Linux 命名空间，控制组 cgroups，以及其它隔离技术。在一个 Pod 的上下文中，可能会对应用程序更进一步的子隔离。

根据 Docker 的概念，一个 Pod 类似于一组共享了命名空间与文件系统卷的 Docker 容器。

### 使用 Pods

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

#### 工作负载资源管理 pods

通常来说用户不需要直接创建 Pods，即使是单例模式的 Pods。相反，而是通过工作负载资源例如 Deployment 或 Job 创建它们。如果 Pods 需要追踪状态，则考虑 StatefulSet 资源。

一个 k8s 集群的 Pods 主要由以下两种方式被使用：

- **运行在单容器的 Pods**：“每个 Pod 一个容器”模型是 k8s 最常用的用例；这种情况下，可以认为是一个 Pod 是一个单独容器的包装；k8s 管理 Pods 而不是直接管理容器。

- **运行在需要一起工作的多容器的 Pods**：一个 Pod 可以封装一个由多个紧密耦合且需要共享资源的并置 co-located 容器构成的应用。这些并置容器构成了一个精密的服务单元，例如，一个容器提供共享卷的数据给公众，而另一个独立的*sidecar*容器则刷新或更新这些文件。Pod 将这些容器和存储资源打包成一个可管理的实体。

> **说明：**将多个并置，同管的容器组织到一个 Pod 中是一种相对高级的使用场景。只有在一些场景中，容器之间紧密关联时才应该使用这种模式。

每个 Pod 意味着运行一个给定应用的单个实例。若果需要平行扩展应用（通过运行更多的单例提供更多的资源），则应该使用若干 Pods，每个实例使用一个 Pod。在 k8s 中，这通常被称为*副本（Replication）*。通常使用一种工作负载资源及其控制器来创建和管理一组 Pod 副本。

#### Pods 如何管理多个容器

Pods 被设计用来支持多个形成内聚服务单元的多个协作过程（形式为容器）。Pod 中的容器将会自动并置 co-located 与共同调度 co-scheduled 在集群中同个物理或虚拟机器。容器之间可以共享资源与依赖，互相通讯，以及协议何时以及如何结束。

例如，可以有一个容器用作于共享卷文件管理的 web 服务，另一个独立的 “sidecar” 容器从远程资源更新这些文件，如下图所示：

{{ image(src="/images/pod.svg", alt="k8s pod") }}

一些 Pods 拥有 Init 容器和应用容器。Init 容器运行并结束于应用容器开始前。

Pods 天生的为其容器成员提供两类共享资源：网络与存储。

### 通过 Pods 工作

用户在 k8s 上很少直接创建独立的 Pods 即便是单例 Pods，是因为 Pods 被设计为相对临时以及可抛弃的实体。当一个 Pod 被创建（直接由用户或是间接被控制器创建），新的 Pod 则会被调度运行在集群中的一个节点上。Pod 会一直保留在该节点上直到 Pod 完成执行，或是 Pod 对象被删除，或是缺少资源 Pod 被*驱逐 evicted*，或是节点失败。

> **注意：**
> 在 Pod 中重启一个容器不应与重启一个 Pod 混淆。一个 Pod 不是一个进程，而是正在运行的容器（们）的环境。一个 Pod 会一直持续到被删除。

当你为 Pod 对象创建清单时，要确保指定的 Pod 名称时合法的 DNS 子域名。

#### Pods 与控制器

可以使用工作负载资源创建并管理若干 Pods。控制器能够处理副本的管理，上线，并在 Pod 失效时提供自愈能力。例如，如果一个节点失败，一个控制器会注意到该节点上的 Pod 停止工作，并创建一个替换用的 Pod。调度器会放置该替换 Pod 到一个健康的节点上。

以下是一些工作负载资源管理一个或多个的案例：

- Deployment
- StatefulSet
- DaemonSet

#### Pod 模板

负载资源的控制器通过*pod 模版*创建 Pod，并为用户管理这些 Pods。

Pod 模版是用于创建 Pods，以及包含类似 Deployment，Jobs，DaemonSets 工作负载资源的规范。

每个负载资源的控制器在工作负载对象中使用 `PodTemplate` 创建真正的 Pods。`PodTemplate` 是用来运行应用时负载资源的期望状态其中的一部分。

下面的案例是一个带有 `template` 用于启动一个容器的 Job 的清单：

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: hello
spec:
  template:
    # This is the pod template
    spec:
      containers:
        - name: hello
          image: busybox:1.28
          command: ["sh", "-c", 'echo "Hello, Kubernetes!" && sleep 3600']
      restartPolicy: OnFailure
    # The pod template ends here
```

修改 Pod 模板或者替换新的 Pod 模板不会直接影响已经存在的 Pods。相反，新的 Pod 会被创建出来，与更改后的 Pod 模板匹配。

例如，StatefulSet 控制器确保每个运行的 Pods 会为每个 StatefulSet 对象匹配当前的 Pod 模版。如果编辑 StatefulSet 修改其 pod 模版，StatefulSet 会根据更新后的模版开始创建新 Pods。最终，所有旧 Pods 会被新 Pods 替换，接着更新完成。

每个负载资源为处理 Pod 模板实现其自身规则。在节点上，kubelet 不会直接观察或管理任何 pod 模版与其更新的细节；这些细节都被抽象出来。这种抽象和关注点分离简化了整个系统的语义，并且使得用户可以再不改变现有代码的前提下就能扩展集群的行为。

### Pod 更新与替换

上一小节中提到，当负载资源的 Pod 模板被修改时，控制器根据更新后的模板创建新的 Pods，而不是更新或修改现有的 Pods。

k8s 不阻止用户直接管理 Pods。更新一些运行中 Pod 的字段是允许的。然而 Pod 类似于 `patch` 与 `replace` 的更新操作有以下一些限制：

- 大多数的 Pod 元数据是不可变的。例如，不可修改 `namespace`，`name`，`uid`，或 `creationTimestamp` 字段；`generation` 字段比较特别，如果更新该字段，只能增加字段取值而不能减少。

- 如果 `metadata.deletionTimestamp` 已经被设置，则不可以向 `metadata.finalizers` 列表中添加新的条目。

- Pod 更新不可以改变除了 `spec.containers[*].image`，`spec.initContainers[*].image`，`spec.activeDeadlineSeconds` 或 `spec.tolerations`。对于 `spec.tolerations` 而言只能添加新的条目。

- 更新 `spec.activeDeadlineSeconds` 字段时，允许两种更新：

  1. 设置未被设置过的字段，可以将其设置为一个正数；

  1. 如果该字段已经设置为一个正数，可以将其设置为一个更小的非负的正数。

### 资源共享与通讯

Pods 允许数据共享以及其成员容器之间的通讯。

#### Pods 中的存储

一个 Pod 可以指定一系列的共享存储卷。Pod 中所有的容器可以访问共享卷，用于容器间的数据共享。卷同样允许在 Pod 中持久化数据，从而在需要重启时生存下来。

#### Pod 的网络

每个 Pod 在每个地址家族中，都会被分配一个独立的 IP 地址。每个 Pod 中的容器共享网络命名空间，包括 IP 地址以及网络端口。**在 Pod 中**，属于 Pod 的容器可以通过 `localhost` 相互进行通讯。当 Pod 中的容器与*Pod 外*的资源通讯时，它们必须协调如何使用共享的网络资源（例如端口）。在一个 Pod 中，容器共享一个 IP 地址以及端口空间，并通过 `localhost` 互相发现。一个 Pod 中的容器同样也可以通过如 SystemV 信号量或者 POSIX 共享内存这样的标准的进程间通信方式来进行相互通讯。不同 Pod 中的容器的 IP 地址互不相同，没有特殊配置，无法通过 OS 级 IPC 进行通信就不能使用 IPC 进行通信。如果某容器希望与运行于其他 Pod 中的容器通信，可以通过 IP 联网的方式实现。

Pod 中的容器所看到的系统主机名与 Pod 配置的 `name` 属性值相同。

### 容器的特权模式

在 Linux 中，Pod 中任何容器都可以使用容器规约中的安全性上下文中的 `privileged`（Linux）参数开启特权模式。这对于想要使用操作系统管理权能（Capabilities，如操纵网络堆栈和访问设备）的容器很有用。

> **说明：**
> 容器运行时必须支持特权容器的概念才能使用这一配置。

### 静态 Pod

*静态 Pod*直接由特定节点上的 `kubelet` 守护进程管理，不需要 API 服务器看到它们。景观大多数 Pod 都是通过控制面（例如 Deployment）来管理的，对于静态 Pod 而言，`kubelet` 直接监控每个 Pod，并在其失效时重启它。

静态 Pod 通常绑定到某个节点上的 kubelet。其主要用途是运行自托管的控制面。在自托管场景中，使用 `kubelet` 来管理每个独立的控制面组件。

`kubelet` 自动尝试为每个静态 Pod 在 k8s 的 API 服务器上创建一个镜像 Pod。这意味着在节点上运行的 Pod 在 API 服务器上是可见的，但是不可以通过 API 服务器来控制。

> **说明：**
> 静态 Pod 的 `spec` 不能引用其他的 API 对象（例如：ServiceAccount，ConfigMap，Secret 等）。

### 容器探针（probes）

**Probe**是由 kubelet 对容器执行的定期诊断。要执行诊断，kubelet 可以执行三种动作：

- `ExecAction`（借助容器运行时执行）
- `TCPSocketAction`（由 kubelet 直接检测）
- `HTTPGetAction`（由 kubelet 直接检测）

## Pod 生命周期

Pods 遵守生命周期的定义，由 `Pending` 阶段（phase）开始，如果至少其中一个主要容器正常启动，进入 `Running` 状态，之后取决于 Pod 中是否有容器以失败状态结束而进入 `Succeeded` 或者 `Failed` 阶段。

一个 Pod 运行时，kubelet 可以重启容器解决一些错误。在 Pod 中，k8s 追踪不同容器的状态，并且决定何种行动使得 Pod 重新健康。

K8s API 中，Pods 同时拥有一个规约部分和实际状态部分。Pod 对象的状态包含了一组 Pod 状况（Conditions）。如果应用需要的话，用户也可以向其注入自定义的就绪性信息。

Pods 在其生命周期中只会被调度一次。一旦 Pod 被调度（分派）到某个节点，Pod 会一直在该节点运行，直到 Pod 停止或者被终止。

### Pod 生命期

与独立应用容器类似，Pods 是由相关联的临时（而不是持久的）实体构成的。Pods 被创建，被赋予一个唯一的 ID（UID），被分调度节点直到终结（根据重启策略）或删除。如果一个节点死亡，被调度到该节点的 Pods 会在超时后被定时删除。

Pods 自身是不会自愈的。如果一个 Pod 被调度到一个节点而节点失败，Pod 会被删除；同样的，因为缺少资源或节点维护，一个 Pod 不会被驱逐后存活。k8s 使用高等级抽象，名为控制器，用于管理这些相对而言可随时丢弃的 Pod 实例。

一个 Pod（由 UID 定义）永远不会被“重新调度”至另一个不同的节点；相反的，Pod 可以被替换成一个新的，几乎相同的 Pod，可以同名，但是 UID 会不同。

如果某事物声称与 Pod 的生命周期相同，例如一个卷 volume，即意味着该事物的存续时间与指定 Pod（同样的 UID）相同。如果 Pod 在任何原因下被删除，甚至完全相同的替代被创建时，其相关内容（卷，本例中）也会被摧毁后重新创建。

### Pod 阶段

Pod 的 `status` 字段是一个 PodStatus 对象，其拥有一个 `phase` 字段。

一个 Pod 的阶段是用于描述 Pod 所处生命周期的一个简单而又高阶的总结。阶段并不是对容器或 Pod 状态的综合汇总，也不是为了成为完整的状态机。

Pod 阶段的数量和含义是严格定义的。除了文档中列举的内容外，不应该再假定有其他的 `phase` 值。

以下是 `phase` 可能的值：

| 数值           | 描述                                                                                                                             |
| -------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| 挂起 Pending   | Pod 被 k8s 集群接受，但是一个或多个容器还未创建以及运行。这里面包含了 Pod 等待被调度的时间，也包含了通过网络下载容器镜像的时间。 |
| 运行 Running   | Pod 已经被绑定至一个节点上，所有的容器都被创建。至少一个容器是在运行着的，或者处于正在启动或正在重启。                           |
| 成功 Succeeded | 所有的容器都已成功终止，并且不会再重启。                                                                                         |
| 失败 Failed    | 所有的容器都已终止，并且至少有一个容器是因为失败终止。也就是说，容器以非 0 状态退出或者被系统终止。                              |
| 未知 Unknown   | 因为某些原因无法取得 Pod 的状态。这种情况通常是因为与 Pod 所在主机通信失败。                                                     |

> **注意：**
> 当一个 Pod 被删除时，它会在一些 kubectl 命令上显示为 `Terminating`。`Terminating` 状态不是任何一个 Pod 的阶段。 一个 Pod 默认拥有 30 秒的优雅终止。用户可以用 --force 标记来强制终止一个 Pod。

如果某节点死亡或者与集群中其他节点失联，k8s 会采取一种策略，将失去的节点上运行的所有 Pod 的 `phase` 设置为 `Failed`。

### 容器状态

总体而已与 Pod 的阶段一样，k8s 追踪 Pod 中每个容器的状态。用户可以使用容器生命周期钩子用以触发容器内部特定的事件。

一旦调度器给节点分配了一个 Pod，kubelet 则会开始使用容器运行时为 Pod 创建容器。容器状态有三种性：`Waiting`，`Running` 与 `Terminated`。

可以使用 `kubectl describe pod <name-of-pod>` 检查 Pod 的容器状态。输出内容会显示改 Pod 中每个容器的状态。

每个状态都有特定的意义：

{% styledblock(class="color-beige") %}

等待 Waiting

{% end %}

一个容器处于 `Waiting` 状态仍然会执行操作以便完成启动：例如，从镜像仓库中拉取容器镜像，或者是应用 Secret 数据。当使用 `kubectl` 查询带有 `Waiting` 状态容器的 Pod 时，同样也可以看到容器为什么处于当前状态的原因信息汇总。

{% styledblock(class="color-beige") %}
运行 Running
{% end %}

`Running` 状态代表着一个容器正在执行并且没有问题。如果有配置过 `postStart` 钩子，那么该回调已经执行且已经完成了。如果使用 `kubectl` 查询带有 `Running` 状态容器的 Pod 时，同样也会看到关于容器进入 `Running` 状态的信息。

{% styledblock(class="color-beige") %}
终结 Terminated
{% end %}

`Terminated` 状态的容器已经开始执行，并会正常结束或是以某些原因失败。使用 `kubectl` 查询带有 `Terminated` 状态容器的 Pod 时，同样也会看到容器进入此状态的原因，退出代码以及容器执行期间的开始结束时间。

如果容器配置了 `preStop` 钩子，则该回调会在容器进入 `Terminated` 状态之前执行。

### 容器重启策略

一个 Pod 的 `spec` 有一个 `restartPolicy` 字段，其可选值为 `Always`，`OnFailure` 以及 `Never`。默认值为 `Always`。

`restartPolicy` 应用于该 Pod 中所有的容器。 `restartPolicy` 仅针对同一节点上 kubelet 的容器。Pod 中容器在退出后，kubelet 根据指数回退方式计算重启延时（10s，20s，40s，...），最长延迟为 5 分钟。一旦某容器执行了 10 分钟且没有出现问题，`kubelet` 对该容器的重启回退计时器则会执行重置操作。

### Pod 状况

WIP

#### Pod 准备

WIP

#### Pod 准备的状态

WIP

### 容器探针

WIP

#### 检查机制

WIP

#### 探测结果

WIP

#### 探测类型

WIP

### Pod 的终止

WIP

#### 强制终止 Pod

WIP

#### 失效 Pod 的垃圾收集

WIP

## Init 容器

WIP

## 干扰

WIP

## 临时容器

WIP

## Downward API

WIP
