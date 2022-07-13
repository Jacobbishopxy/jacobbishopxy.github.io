+++
title="K8s 笔记 (II)"
description="集群架构"
date=2022-07-12

[taxonomies]
categories = ["Doc"]
tags = ["k8s"]

[extra]
toc = true
+++

## 节点

k8s 通过放置容器进入 Pods 运行在*节点*上从而运行负载。一个节点可能是虚拟的或者是物理机器，这取决于集群。每个节点都是通过控制面进行管理，并且包含了运行在 Pods 的服务。

一个节点的组件包含了 kubelet，一个容器运行时，以及一个 kube-proxy。

### 节点管理

有两种主要的方法用于添加节点至 API 服务：

1. 节点上的 `kubelet` 向控制面执行自注册；
1. 用户手动添加一个 Node 对象。

创建节点对象后，控制面会检查该节点是否可用。例如，如果尝试通过以下 JSON 创建一个节点：

```JSON
{
  "kind": "Node",
  "apiVersion": "v1",
  "metadata": {
    "name": "10.240.79.157",
    "labels": {
      "name": "my-first-k8s-node"
    }
  }
}
```

k8s 创建一个内部的节点对象，接着检查一个在 API 服务上注册过的 kubelet 是否匹配节点的 `metadata.name` 字段。如果该节点是健康的（例如所有的服务都在运行），那么它可以运行一个 pod。否者该节点会被任何集群的行动所忽略，直到该节点恢复健康。

> 注意：k8s 会保留不可用节点的对象以及持续检查该节点是否恢复健康。用户或者控制器需要显式的删除节点对象以便停止健康检查。

名称用于标识节点，在同一时刻下不可以有两个相同名称的节点。k8s 同样也假设拥有同一名称的资源是同一个对象。

当 kubelet 标记 `--register-node` 为真时（即默认），kubelet 会尝试通过 API 服务进行自注册。这是首选的模式，大多数版本都会这样。

关于自注册，kubelet 有下面几个选项：

- `--kubeconfig`：用于向 API 服务器执行身份认证所用的凭据的路径。
- `--cloud-provider`：与与驱动进行通信以读取与自身相关的元数据的方式。
- `--register-node`：自动向 API 服务注册。
- `--register-with-taints`：使用所给的污点列表（逗号分隔的 `<key>=<value>:<effect>`）注册节点。当 `register-node` 为 false 时无效。
- `--node-ip`：节点 IP 地址。
- `--node-labels`：在集群注册节点时所添加的标签。
- `--node-status-update-frequency`：制定 kubelet 向控制面发生状态的频率。

也可以使用 kubectl 来手动创建和修改 Node 对象，这时需要设置 `--register-node=false`。

### 节点状态

一个节点的状态包含以下信息：

- 地址
- 条件
- 容量与分配
- 信息

可以使用 `kubectl` 查看节点状态以及其他细节：

```sh
kubectl describe node <insert-node-name-here>
```

地址这个字段的使用取决于云服务商或者物理机的配置：

- HostName：有节点的内核报告。可以通过 kubelet 的 `--hostname-override` 参数覆盖。
- ExternalIP：通常是节点的可外部路由（从集群外可访问）的 IP 地址。
- InternalIP：通常是节点的仅可在集群内部路由的 IP 地址。

`conditions` 字段描述了所有 `Running` 节点的状态。例如状态包括：

| 节点条件           | 描述                                                                                                                                                                              |
| ------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Ready              | True 如果节点是健康的并且准备接受 pods，False 如果节点是不健康的以及未接受 pods，以及 Unknown 如果节点控制器在节点的最后 node-monitor-grace-period （默认为 40 秒）上没有获得相应 |
| DiskPressure       | True 如果磁盘大小存在压力，也就是说空间很小；否者 False                                                                                                                           |
| MemoryPressure     | True 如果节点内存存在压力，也就是说节点内存不足；否者 False                                                                                                                       |
| PIDPressure        | True 如果进程存在压力，也就是说有太多的进程在此节点上了；否者 False                                                                                                               |
| NetworkUnavailable | True 如果节点的网络没有被正确的配置；否者 False                                                                                                                                   |

> 注意：如果使用命令行工具打印已保护（Cordoned）节点的细节，其中的条件字段可能包括 `SchedulingDisabled`。它不是 k8s API 定义的条件，被保护起来的节点在其规则中被标记为不可调度（Unschedulable）。

在 k8s API 中，节点的状态标识节点资源中 `.status` 的一部分。例如以下 JSON 结构描述了一个健康节点：

```json
"conditions": [
  {
    "type": "Ready",
    "status": "True",
    "reason": "KubeletReady",
    "message": "kubelet is posting ready status",
    "lastHeartbeatTime": "2019-06-05T18:38:35Z",
    "lastTransitionTime": "2019-06-05T11:41:27Z"
  }
]
```

如果准备条件的 `status` 一直保持着 `Unknown` 或是 `False` 状态，并超过了 `pod-eviction-timeout`（即传给 k8s 控制器管理者 kube-controller-manager 的一个参数），那么节点控制器触发 API 发起的驱逐。默认的驱逐超时时长为 5 分钟。某些情况下当一个节点不可获取时，API 服务不能与节点的 kubelet 进行交互。那么删除节点的决策不能传递给 kubelet 直到 API 服务重新被连接。在此期间，被计划删除的 pods 可能会继续在部分节点上运行。

节点控制器不会强制删除 pods 直到它确认了它们被集群停止运行。用户有可能会看到 pods 运行在一个标记为 `Terminating` 或 `Unknown` 状态的不可获取的节点上。为了以防万一 k8s 在一个节点永久离开集群时，不能由下层基础设施推断出来，集群管理者可能需要手动删除该节点对象。从 k8s 删除节点对象会导致所有运行在节点的 Pod 从 API 服务中删除，同时释放它们的名称。

当节点出现问题时，k8s 控制面会为收到影响的节点们自动的创建污点。当需要分配 pod 给节点时，调度器则会考虑到这些污点。Pod 也可以设置容忍度，使得在设置了特定污点的节点上运行。

容量 capacity 与可分配 allocatable 这两个值描述了节点上的可用资源：CPU，内存，以及可用于调度给节点的最大 pods 数。“容量”的字段代表着一个节点的整体资源；“可分配”的字段代表着一个节点可被消费的整体资源。

信息 info 描述了节点的信息，例如内核版本，k8s 版本（kubelet 与 kube-proxy 的版本），容器运行时的细节，以及节点所使用的操作系统。kubelet 从节点中收集了这些信息并发布进 k8s API。

### 心跳

心跳，由 k8s 节点发送，帮助集群控制各个节点的可用性，以及对于失败做出相应的动作。对于节点而言，有两种形式的心跳：

- 更新节点的 `.status`。
- 在 `kube-node-lease` 命名空间内租借 lease 对象。每个节点都有一个关联的租借对象。

相比于更新节点的 `.status`，Lease 是一个轻量级的资源。对于大型集群而言，通过 leases 可以减少更新所带来的性能影响。

kubelet 负责创建与更新节点的 `.status`，同时也更新这些节点所关联的 lease。

- kubelet 会在节点状态变化或者配置的时间区间没有更新时，更新节点的 `.status`。默认的节点更新 `.status` 的时间区间为 5 分钟，远比 40 秒的不可获取节点的默认时间要长。
- kubelet 会每隔 10 秒（默认的更新时间区间）创建并更新 lease 对象。lease 的更新独立与节点 `.status` 的更新。如果 lease 更新失败，kubelet 会使用指数回退机制，从 200 毫秒开始重试，最长重试间隔为 7 秒钟。

### 节点控制器

节点控制器是 k8s 控制面中用于在多个层面上进行节点管理的组件。其在节点的生命周期中担任了多个角色。首先是当节点被注册是指定 CIDR 区段（如果开启了 CIDR 分配）。其次是维护控制器的内部节点列表与云服务商所提供的可用机器列表同步。如果在云环境下运行，只要某个节点不健康，节点控制器就会询问云服务节点的虚拟机是否仍然可用。如果不可用，节点控制器会将该节点从节点列表中删除。再者是监控节点的健康状况，负责以下：

- 在节点不可获取的情况下，在节点的 `.status` 中更新 `Ready` 的状态并改为 `Unknown`。
- 如果节点仍然无法访问，对于不可获取的节点上的所有 Pod 触发 API 发起的驱逐操作。默认情况节点控制器在将节点标记为 `Unknown` 后等待 5 分钟后提交第一个驱逐请求。

### 资源容量追踪

节点对象追踪节点资源容量的信息：比如可用的内存与 CPU 的数量。通过自注册机制生成的节点对象会在注册期间报告自身容量。如果是手动的添加节点，那么也需要手动的设置节点容量。k8s 调度器保证节点上有足够的资源提供给所有的 pod 使用。它会检查节点上所有容器的请求的总和不会超过节点的容量。中的请求包括由 kubelet 启动的所有容器，但不包括容器运行时直接启动的容器，也不包括不受 kubelet 控制的其它进程。

### 节点的优雅关闭

**特性状态**：`v1.21 [beta]`

kubelet 会尝试检测节点系统的关闭以及终止在节点上运行的 pods，并确保 pods 遵从 pod 终止流程。优雅关闭依赖于 systemd，因为利用了 systemd 的抑制器锁机制，在给定的期限内延迟节点关闭。优雅关闭这个特性受 `GracefulNodeShutdown` 控制门所控制，在 1.21 版本中是默认启用的。注意在默认情况下，下面描述的两个配置选项 `shutdownGracePeriod` 与 `shutdownGracePeriodCriticalPods` 的设置都为 0。因此不会激活节点优雅关闭功能。要激活该功能特性，这两个 kubelet 配置选项要适当配置，并设置为非零值。

在优雅关闭节点的过程中 kubelet 分两个阶段来终止 Pod：

1. 终止在节点上运行的常规 Pod
1. 终止在节点上运行的关键 Pod

优雅关闭的特性对应两个 `KubeletConfiguration` 选项：

- `shutdownGracePeriod`：指定节点应延迟关闭的总持续时间。改时间为 Pod 优雅终止的时间总和，不区分常规 Pod 或是关键 Pod。
- `shutdownGracePeriodCriticalPods`：节点关闭期间指定用于终止关键 Pod 的持续时间。该值应该小于 `shutdownGracePeriod`。

### 节点的非优雅关闭

**特性状态**：`v1.24 [alpha]`

一个节点的关闭可能不会被 kubelet 的节点管理所监控，这有可能是因为命令没有触发 kubelet 使用的抑制器锁机制或是因为一个用户的错误，例如 `shutdownGracePeriod` 和 `shutdownGracePeriodCriticalPods` 没有被正确的配置。

当节点的关闭并没有被 kubelet 管理所监控时，StatefulSet 部分的 pods 会停滞在终止的状态中，并且不能移动至新的节点上。这是因为 kubelet 在关闭的节点上不能删除 pods，因此 StatefulSet 不能创建同名的新 pod。如果 pods 还用到了 volume，那么 VolumeAttachments 也不会在原有节点上被删除，因此这些 pods 所使用的 volumes 也不能被挂载到新的运行的节点上。因此 StatefulSet 上运行的应用程序不能正常工作。如果原来的已关闭节点被恢复，kubelet 将删除 Pod，新的 Pod 将在不同的运行节点上创建。如果原来的已关闭节点没有被恢复，那些在已关闭节点上的 Pod 将永远停滞在终止状态。

为了缓解上述状况，用户可以手动将 `NoExecute` 或者 `NoSchedule` 效果的 `node kubernetes.io/out-of-service` 污点添加到节点上，标记其无法提供服务。如果在 `kube-controller-manager` 上启用了 `NodeOutOfServiceVolumeDetach` 特性门控，并且节点被标记污点，同时如果节点 Pod 上没有设置对应的容忍度，那么这样的 Pod 将会被强制删除，并且 Pod 的 volume 会被立刻分离。这可以让在无法服务的节点上的 Pods 快速在另一个节点上恢复。

在非优雅关闭节点过程中，Pod 分两个阶段终止：

1. 强制删除没有匹配的 `out-of-service` 容忍度的 Pod。
1. 立刻对此类 Pod 执行分离 volume 操作。

### 内存交换管理

**特性状态**：`v1.22 [alpha]`

在 1.22 版本之前 k8s 不支持交换内存，如果在一个节点上检查到交换 kubelet 则默认会启动失败。在 1.22 版本之后，可以逐个节点启用交换内存支持。要在节点上启用交换内存，必须启用 kubelet 的 `NodeSwap` 特性门控，同时使用 `--fail-swap-on` 命令行参数或者将 `failSwapOn` 配置设置为 false。用户还可以选择配置 `memorySwap.swapBehavior` 来指定交换内存的方式，例如：

```yaml
memorySwap:
  swapBehavior: LimitedSwap
```

## 节点与控制面的通信

本文档说明 API 服务与 k8s 集群的通信路径。目的是为了让用户能够自定义安装，实现对网络配置的加固，使得集群能够在不可信的网络上（或者一个云服务商完全公开的 IP 上）运行。

### 节点到控制面

k8s 采用的是中心辐射型 Hub-and-Spoke API 模式。所有从节点（或运行的 Pod）发出的 API 调用都终止于 API 服务器。其它控制面组件都没有被设计为可暴露远程服务。API 服务器被配置在一个安全的 HTTPS 端口（通常为 443）上监听远程连接请求，并启用一种或多种形式的客户端身份认证机制。客户端的鉴权机制应该被启用，特别是在允许使用匿名请求或服务账户令牌时。

节点应该被预先分配集群的公共根证书，这样它们可以通过合法的客户认证安全连接到 API 服务。一个良好的实现是以客户端证书的形式将客户端凭据提供给 kubelet。

想要连接到 API 服务器的 Pod 可以使用服务账号安全的进行连接。当 Pod 被实例化时，k8s 自动把公共根证书和一个有效的持有者令牌注入到 Pod 里。`kubernetes` 服务（位于 `default` 命名空间内）配置了一个虚拟 IP 地址，用于（通过 kube-proxy）转发请求到 API 服务器的 HTTPS 末端。

控制面组件控制面也通过安全端口与集群的 API 服务器通信。从集群节点和节点上运行的 Pod 到控制面的连接的默认操作模式是安全的，能够在不可信的网络或公网上运行。

### 控制面到节点

控制面（API 服务）到节点主要有两种通信路径。第一种是从 API 服务到集群上每个节点上的 kubelet 进程；第二种是 API 服务通过自身的 proxy 功能到任意节点，pod 或者服务。

#### API 服务到 kubelet

用于：

- 获取 Pod 日志
- 挂接（通过 kubectl）到运行中的 Pod
- 提供 kubelet 的端口转发功能

这些连接终止于 kubelet 的 HTTPS 末端。默认情况下，API 服务器不检查 kubelet 的服务证书。这使得此类连接容易受到中间人攻击，在非授信网络或公开网络上运行也是**不安全的**。为了对连接进行认证，使用 `--kubelet-certificate-authority` 标志给 API 服务器提供一个根证书包，用于 kubelet 的服务证书。最后应该启用 kubelet 用户认证和/或鉴权来保护 kubelet API。

#### API 服务到节点，pods 和服务

从 API 服务器到节点，Pod 或服务的默认连接为纯 HTTP 方式，既没有认证，也没有加密。这些连接可通过给 API URL 中的节点，Pod 或服务器名称添加前缀 `https:` 来运行在安全的 HTTPS 连接上。不过这些连接既不会验证 HTTPS 末端提供的证书，也不会提供客户端证书。因此连接虽然是加密的，仍然无法提供任何完整性的保证。这些连接**目前还不能安全的**在非授信网络或公共网络上运行。

#### Konnectivity 服务

**特性状态**：`v1.18 [beta]`

作为 SSH 隧道的替代方案，Konnectivity 服务提供 TCP 层的代理，支持从控制面到集群的通信。Konnectivity 服务包含两个部分：Konnectivity 服务器和 Konnectivity 代理， 分别运行在控制面网络和节点网络中。 Konnectivity 代理建立并维持到 Konnectivity 服务器的网络连接。 启用 Konnectivity 服务之后，所有控制面到节点的通信都通过这些连接传输。
