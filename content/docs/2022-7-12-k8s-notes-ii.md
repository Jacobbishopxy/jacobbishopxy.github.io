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

k8s 通过放置容器进入 Pods 运行在*节点*上从而运行负载。一个节点可能是虚拟的或者是物理机器，这取决于集群。每个节点都是通过控制面板进行管理，并且包含了运行在 Pods 的服务。

一个节点的组件包含了 kubelet，一个容器运行时，以及一个 kube-proxy。

### 节点管理

有两种主要的方法用于添加节点至 API 服务：

1. 节点上的 `kubelet` 向控制面执行自注册；
1. 用户手动添加一个 Node 对象。

创建节点对象后，控制面板会检查该节点是否可用。例如，如果尝试通过以下 JSON 创建一个节点：

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
- `--node-status-update-frequency`：制定 kubelet 向控制面板发生状态的频率。

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

当节点出现问题时，k8s 控制面板会为收到影响的节点们自动的创建污点。当需要分配 pod 给节点时，调度器则会考虑到这些污点。Pod 也可以设置容忍度，使得在设置了特定污点的节点上运行。

容量 capacity 与可分配 allocatable 这两个值描述了节点上的可用资源：CPU，内存，以及可用于调度给节点的最大 pods 数。“容量”的字段代表着一个节点的整体资源；“可分配”的字段代表着一个节点可被消费的整体资源。

信息 info 描述了节点的信息，例如内核版本，k8s 版本（kubelet 与 kube-proxy 的版本），容器运行时的细节，以及节点所使用的操作系统。kubelet 从节点中收集了这些信息并发布进 k8s API。

### 心跳

### 节点控制器

### 资源容量追踪

### 节点的拓扑

### 节点的优雅关闭

### 节点的非优雅关闭

### 内存交换管理
