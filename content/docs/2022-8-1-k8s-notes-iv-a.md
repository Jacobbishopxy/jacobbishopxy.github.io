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

{% blockquote_note() %}
除了 Docker，k8s 支持很多的容器运行时，而 Docker 是最为熟知的运行时，使用 Docker 的术语描述 Pod 会很有帮助。
{% end %}

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

{% blockquote_note() %}
将多个并置，同管的容器组织到一个 Pod 中是一种相对高级的使用场景。只有在一些场景中，容器之间紧密关联时才应该使用这种模式。
{% end %}

每个 Pod 意味着运行一个给定应用的单个实例。若果需要平行扩展应用（通过运行更多的单例提供更多的资源），则应该使用若干 Pods，每个实例使用一个 Pod。在 k8s 中，这通常被称为*副本（Replication）*。通常使用一种工作负载资源及其控制器来创建和管理一组 Pod 副本。

#### Pods 如何管理多个容器

Pods 被设计用来支持多个形成内聚服务单元的多个协作过程（形式为容器）。Pod 中的容器将会自动并置 co-located 与共同调度 co-scheduled 在集群中同个物理或虚拟机器。容器之间可以共享资源与依赖，互相通讯，以及协议何时以及如何结束。

例如，可以有一个容器用作于共享卷文件管理的 web 服务，另一个独立的 “sidecar” 容器从远程资源更新这些文件，如下图所示：

{{ image(src="/images/pod.svg", alt="k8s pod") }}

一些 Pods 拥有 Init 容器和应用容器。Init 容器运行并结束于应用容器开始前。

Pods 天生的为其容器成员提供两类共享资源：网络与存储。

### 通过 Pods 工作

用户在 k8s 上很少直接创建独立的 Pods 即便是单例 Pods，是因为 Pods 被设计为相对临时以及可抛弃的实体。当一个 Pod 被创建（直接由用户或是间接被控制器创建），新的 Pod 则会被调度运行在集群中的一个节点上。Pod 会一直保留在该节点上直到 Pod 完成执行，或是 Pod 对象被删除，或是缺少资源 Pod 被*驱逐 evicted*，或是节点失败。

{% blockquote_note() %}
在 Pod 中重启一个容器不应与重启一个 Pod 混淆。一个 Pod 不是一个进程，而是正在运行的容器（们）的环境。一个 Pod 会一直持续到被删除。
{% end %}

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

{% blockquote_note() %}
容器运行时必须支持特权容器的概念才能使用这一配置。
{% end %}

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

{% blockquote_note() %}
当一个 Pod 被删除时，它会在一些 kubectl 命令上显示为 `Terminating`。`Terminating` 状态不是任何一个 Pod 的阶段。 一个 Pod 默认拥有 30 秒的优雅终止。用户可以用 --force 标记来强制终止一个 Pod。
{% end %}

如果某节点死亡或者与集群中其他节点失联，k8s 会采取一种策略，将失去的节点上运行的所有 Pod 的 `phase` 设置为 `Failed`。

### 容器状态

总体而已与 Pod 的阶段一样，k8s 追踪 Pod 中每个容器的状态。用户可以使用容器生命周期钩子用以触发容器内部特定的事件。

一旦调度器给节点分配了一个 Pod，kubelet 则会开始使用容器运行时为 Pod 创建容器。容器状态有三种性：`Waiting`，`Running` 与 `Terminated`。

可以使用 `kubectl describe pod <name-of-pod>` 检查 Pod 的容器状态。输出内容会显示改 Pod 中每个容器的状态。

每个状态都有特定的意义：

{% styled_block(class="color-beige") %}
等待 Waiting
{% end %}

一个容器处于 `Waiting` 状态仍然会执行操作以便完成启动：例如，从镜像仓库中拉取容器镜像，或者是应用 Secret 数据。当使用 `kubectl` 查询带有 `Waiting` 状态容器的 Pod 时，同样也可以看到容器为什么处于当前状态的原因信息汇总。

{% styled_block(class="color-beige") %}
运行 Running
{% end %}

`Running` 状态代表着一个容器正在执行并且没有问题。如果有配置过 `postStart` 钩子，那么该回调已经执行且已经完成了。如果使用 `kubectl` 查询带有 `Running` 状态容器的 Pod 时，同样也会看到关于容器进入 `Running` 状态的信息。

{% styled_block(class="color-beige") %}
终结 Terminated
{% end %}

`Terminated` 状态的容器已经开始执行，并会正常结束或是以某些原因失败。使用 `kubectl` 查询带有 `Terminated` 状态容器的 Pod 时，同样也会看到容器进入此状态的原因，退出代码以及容器执行期间的开始结束时间。

如果容器配置了 `preStop` 钩子，则该回调会在容器进入 `Terminated` 状态之前执行。

### 容器重启策略

一个 Pod 的 `spec` 有一个 `restartPolicy` 字段，其可选值为 `Always`，`OnFailure` 以及 `Never`。默认值为 `Always`。

`restartPolicy` 应用于该 Pod 中所有的容器。 `restartPolicy` 仅针对同一节点上 kubelet 的容器。Pod 中容器在退出后，kubelet 根据指数回退方式计算重启延时（10s，20s，40s，...），最长延迟为 5 分钟。一旦某容器执行了 10 分钟且没有出现问题，`kubelet` 对该容器的重启回退计时器则会执行重置操作。

### Pod 状况

Pod 的 PodStatus 是一个包含 PodConditions 的数组。其中是 Pod 可能通过的测试：

- `PodScheduled`：Pod 被调度去一个节点。
- `ContainersReady`：Pod 中所有容器就绪。
- `Initialized`：所有 init 容器成功完成。
- `Ready`：Pod 可以为请求提供服务，并且应该被添加至所有匹配服务的负载均衡池。

| 数值               | 描述                                                           |
| ------------------ | -------------------------------------------------------------- |
| type               | Pod 状况的名称                                                 |
| status             | 表明该状况是否适用，可能的值为"True"，"False" 或者 "Unknown"。 |
| lastProbeTime      | 上次探测 Pod 状况时的时间戳                                    |
| lastTransitionTime | 上次探测 Pod 转换状态时的时间戳                                |
| reason             | 机器可读的，驼峰编码的文字，表述上次状况变化的原因             |
| message            | 人类可读的消息，表明上次状态转换的详细信息                     |

#### Pod 就绪

**特性状态**：`v1.14 [stable]`

用户的应用程序可以注入额外的反馈或者信号至 PodStatus：Pod 就绪（Pod Readiness）。要使用这个特性，可以在 Pod 的 `spec` 设置 `readinessGates` 列表，来为 kubelet 提供一组额外的状况供其评估 Pod 就绪时使用。

就绪门控 Readiness gates 根据 `status.condition` 字段现有的状态决定。如果 k8s 不能发现 Pod 中 `status.conditions` 字段中某一个状况，那么该状况的默认值为 "`False`"。

这里是一个例子：

```yaml
kind: Pod
---
spec:
  readinessGates:
    - conditionType: "www.example.com/feature-1"
status:
  conditions:
    - type: Ready # a built in PodCondition
      status: "False"
      lastProbeTime: null
      lastTransitionTime: 2018-01-01T00:00:00Z
    - type: "www.example.com/feature-1" # an extra PodCondition
      status: "False"
      lastProbeTime: null
      lastTransitionTime: 2018-01-01T00:00:00Z
  containerStatuses:
    - containerID: docker://abcd...
      ready: true
```

所添加的 Pod 状况名称必须满足 k8s 标签键名格式。

#### Pod 就绪的状态

`kubectl patch` 命令不支持修改对象状态。为 pod 设置 `status.conditions`，应用程序以及 operators 需要使用 `PATCH` 操作。用户可以使用 k8s 客户端库来编写代码为 Pod 就绪设置自定义的 Pod 状况。

对于使用自定义状况而言，Pod 只有满足下列表述才会被评估为就绪：

- Pod 中所有容器都已就绪；
- `readinessGates` 中的所有状况都为 `True` 值。

当 Pod 容器都已就绪，但至少一个自定义状况没有值或者值为 `False`，kubelet 设置 Pod 的状况为 `ContainersReady`。

### 容器探针

*探针 probe*是 kubelet 用于间断性的诊断容器的工具。kubelet 在容器中执行代码或者发起一个网络请求来执行诊断。

#### 检查机制

使用探针检查容器有四种不同的方法。每个探针必须定义下述四种机制的一种：

{% styled_block(class="color-beige font-bold") %}
exec
{% end %}

在容器中执行指定的命令。如果命令返回的状态码为 0，那么诊断被视为成功。

{% styled_block(class="color-beige font-bold") %}
grpc
{% end %}

使用 gRPC 进行远程过程调用。目标需要实现 gRPC 健康检查。如果响应的状态为 SERVING 那么诊断视为成功。

{% styled_block(class="color-beige font-bold") %}
httpGet
{% end %}

对 Pod 的 IP 地址以及特定端口与路径，使用 HTTP GET 请求。如果响应的状态代码大于等于 200 并小于 400，那么诊断视为成功。

{% styled_block(class="color-beige font-bold") %}
tcpSocket
{% end %}

对 Pod 的 IP 地址以及特定端口，使用 TCP 检查。如果远程系统（即容器）在连接建立后立刻关闭连接，视为健康。

#### 探测结果

每个探针都有以下三个结果之一：

{% styled_block(class="color-beige font-bold") %}
Success
{% end %}

容器通过了诊断。

{% styled_block(class="color-beige font-bold") %}
Failure
{% end %}

容器没有通过诊断。

{% styled_block(class="color-beige font-bold") %}
Unknown
{% end %}

诊断失败（没有执行操作，kubelet 将会进一步检查）

#### 探测类型

kubelet 可以选择性的执行和响应三种类型的容器探针：

{% styled_block(class="color-beige font-bold") %}
存活探针 livenessProbe
{% end %}

表明容器是否正在运行。如果存活探针失败，kubelet 则会杀死容器，容器受到重启策略影响。如果一个容器没有提供存活探针，默认的状态则是*Success*。

{% styled_block(class="color-beige font-bold") %}
就绪探针 readinessProbe
{% end %}

表明容器是否就绪对请求进行响应。如果就绪探针失败，那么端点控制器则会从所有匹配该 Pod 服务的端点列表中，移除该 Pod 的 IP 地址。在初次延迟之前的默认就绪值为*Failure*。如果一个容器没有提供就绪探针，则默认值为*Success*。

{% styled_block(class="color-beige font-bold") %}
启动探针 startupProbe
{% end %}

表明容器中的应用是否已经启动。如果提供了启动探针，其余的探针都会被禁用，直到其成功。如果启动探针失败，kubelet 则会杀死容器，容器受到重启策略影响。如果容器没有提供启动探针，则默认值为*Success*。

##### 何时该使用存活探针？

**特性状态**：`v1.0 [stable]`

如果容器中的进程能够在遇到问题或不健康的情况下自行崩溃，则不一定需要存活探针；`kubelet` 将根据 Pod 的 `restartPolicy` 自动执行修复操作。

如果用户希望容器在探测失败时被杀死并重启，那么请指定一个存活探针，并指定 `restartPolicy` 为 `"Always"` 或 `"OnFailure"`。

##### 何时该使用就绪探针？

**特性状态**：`v1.0 [stable]`

如果要尽在探测成功时才开始向 Pod 发送请求流量，请指定就绪探针。这种情况下，就绪探针可能与存货探针相同，但是规约中的就绪探针的存在意味着 Pod 将在启动阶段不接受任何数据，并且只有在探针探测成功后才开始接收数据。

如果用户希望容器能够自行进入维护状态，也可以指定一个就绪探针，检查一个不同于存活探针的就绪端点。

如果用户的应用程序对后端服务有严格的依赖性，则可以同时实现存活探针与就绪探针。当应用程序本身是健康的，存活探针检测通过后，就绪探针会额外检查每个所需的后端服务是否可用。这样可以帮助用户避免将流量导向只能返回错误信息的 Pod。

如果用户的容器需要在启动期间加载大型数据，配置文件或执行迁移，则可以使用启动探针。然而，如果只想区分已经失败的应用和仍在处理其启动数据的应用，则更倾向于使用就绪探针。

{% blockquote_note() %}
注意如果只想在 Pod 被删除时能够排空请求，则不一定需要使用就绪探针；删除 Pod 时，Pod 会自动将自身置于未就绪状态，无论就绪探针是否存在。等待 Pod 中的容器停止期间，Pod 会一直处于未就绪状态。
{% end %}

##### 何时该使用启动探针？

**特性状态**：`v1.20 [stable]`

Pod 中所包含的容器需要较长时间才能启动好，那么启动探针是有用的。用户不再需要配置一个较长的存活探测时间间隔，只需要设置另一个独立的配置选定对启动期间的容器进行探测，从而允许使用远超出存活时间间隔所允许的时长。

如果容器启动时间通常超出 `initialDelaySeconds + failureThreshold * periodSeconds` 总值，则应该设置一个启动探针，对存活探针所使用的同一端点执行检查。`periodSeconds` 的默认值是 10 秒。用户应该将其 `failureThreshold` 设置的很高，以便容器有充足的时间完成启动，并且避免更改存活探针所使用的默认值。改设置有利于减少死锁的发生。

### Pod 的终止

因为 Pods 代表着运行在集群中节点的进程，当这些进程不再被需要时（不是通过 `KILL` 信号，粗暴的停止并且无法再被清除），允许它们能够优雅的终结是很重要的。

该设计提供用户请求删除并且知道何时进程终结，同时能确保这些删除最终能够完成。当用户请求删除一个 Pod，集群会在 Pod 被强制杀死之前，记录并追踪预期的时间。在存在强制关闭的前提下，kubelet 会尝试优雅的关闭。

通常情况下，容器运行时发送一个 TERM 信号到每个容器的主进程。很多容器运行时都能注意到容器镜像中所定义的 `STOPSIGNAL` 值，发送该信号而不是 TERM。一旦超出了优雅终结的期限，容器运行时会像所有剩余进程发送 KILL 信号，之后 Pod 就会被从 API 服务器上移除。如果 `kubelet` 或者容器运行时的管理服务在等待进程终止期间被重启，集群则会从头开始重试，给予 Pod 完成的优雅终结期限。

#### 强制终止 Pod

默认情况下，所有的删除都是优雅的带有 30 秒期限。`kubectl delete` 命令提供 `--grace-period=<seconds>` 选项让用户覆盖该默认值。

设置优雅期间为 `0` 意味着立刻从 API 服务器删除 Pod。如果 Pod 仍然运行在某节点上，强制删除操作会触发 `kubelet` 立刻执行清理操作。

执行强制删除操作时，API 服务器不再等待来自 `kubelet` 的，关于 Pod 已经在原来运行的节点上终止执行的确认消息。API 服务器直接删除 Pod 对象，这样新的与之同名的 Pod 可以被创建。在节点上，被设置立刻终止的 Pod 仍然会在被强行杀死之前获得一些时间期限。

#### 失效 Pod 的垃圾收集

对于已失败的 Pod 而言，对应的 API 对象仍然会保留在集群的 API 服务器上，直到用户或者控制器进程显式的删除它。

控制面组件会在 Pod 个数超出所配置的阈值（基于 `kube-controller-manager` 的 `terminated-pod-gc-threshold` 设置）时删除已终止的 Pod（阶段值为 `Succeeded` 或 `Failed`）。这一行为会避免随着时间不断创建和终止 Pod 而引起的资源泄漏问题。

## Init 容器

WIP

## 干扰

WIP

## 临时容器

WIP

## Downward API

WIP
