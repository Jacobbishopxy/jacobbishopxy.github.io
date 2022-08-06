+++
title="K8s 笔记 (V)"
description="服务，负载均衡和网络"
date=2022-09-01

[taxonomies]
categories = ["Doc"]
tags = ["k8s"]

[extra]
toc = true
+++

## 简介

### K8s 网络模型

每个在集群里的 `Pod` 都有其唯一的 IP 地址。这就意味着用户不需要显式的创建 `Pods` 直接的连接，同时几乎不用处理容器端口与主机端口的映射。这就创建了一个干净的，向后兼容的模型，从端口分配，命名，服务发现，负载均衡，应用配置和迁移的角度来看，`Pods` 可以被视为 VMs 或者物理主机。

对任何网络设施，k8s 强制要求下列基础需求（使得排除掉有意隔离网络的策略）：

- Pod 能够与其他节点上的 Pod 通信，且不需要网络地址转译（NAT）
- 节点上的代理（比如：系统守护进程，kubelet）可以和节点上的所有 Pod 通信

注意：这些支持 `Pods` 运行在主机网络（例如 Linux）的平台，当 pods 连接到一个节点的主机网络，它们仍然可以不使用 NAT 与其他所有节点的 pods 通信。

这个模型不仅不复杂，而且还和 k8s 的实现从虚拟机向容器平滑迁移的初衷相符，如果任务开始是在虚拟机中运行的，虚拟机有一个 IP，可以和项目中其他虚拟机通信。这里的模型是基本相同的。

k8s 的 IP 地址存在于 `Pod` 范围内 -- 容器共享它们的网络命名空间 -- 包括它们的 IP 地址和 MAC 地址。这就意味着 `Pod` 内的容器都可以通过 `localhost` 到达对方端口。这也就意味着 `Pod` 内的容器需要相互协调端口的使用，这和虚拟机中的进程相同，因此也被称为”一个 Pod 一个 IP“模型。

如何实现上述需求是使用的特定容器运行时的细节。

也可以在 `Node` 本身请求端口，并用这类端口转发到用户的 `Pod`（称之为主机端口），但这是一个很特殊的操作。转发方式如何实现也是容器运行时的细节。`Pod` 自己并不知道这些主机端口的存在。

k8s 网络解决四方面的问题：

- 一个 Pod 中的容器之间通过本地回路（loopback）通信。
- 集群网络在不同 pod 之间提供通信。
- 服务资源允许用户向外暴露 Pods 中运行的应用，用来支持来自于集群外部的访问。
- 可以使用服务来发布仅供集群内部使用的服务。

## 服务 Service

将运行在一组 Pods 上的应用程序公开为网络服务的抽象方法。

使用 k8s，用户无需修改应用程序即可使用不熟悉的服务发现机制。k8s 为 Pod 提供自己的 IP 地址，并为一组 Pod 提供相同的 DNS 名，并且可以在它们之间进行负载均衡。

### 动机

k8s Pods 的创建与销毁用于匹配集群的期望状态。Pod 是非永久性的资源。如果使用 Deployment 来运行应用程序，则可以动态创建和销毁 Pod。

每个 Pod 都有自己的 IP 地址，但是在 Deployment 中，在同一时刻运行的 Pod 集合可能会稍后运行该应用程序的 Pod 集合不同。

这导致了一个问题：如果一组 Pod（称为“后端”）为集群内的其他 Pod（称为“前端”）提供功能，那么前端如何找出并跟踪要连接的 IP 地址，以便前端可以使用提供工作负载的后端部分？

进入*Services*。

### Service 资源

k8s 中 Service 定义了这样一种抽象：逻辑上的一组 Pod，一种可以访问它们的策略 -- 通常称为微服务。Service 所针对的 Pod 集合通常是通过选择算符来确定的。

例如，一个图片处理后端，运行了 3 个副本。这些副本是可以互换的 -- 前端不需要关心它们调用了哪个后端副本。然而组成这一组后端程序的 Pod 实际上可能会发生变化，前端客户端不应该也不需要直到，而且也不需要跟踪这一组后端的状态。

Service 定义的抽象能够解耦这种关联。

### 定义 Service

k8s 中的 Service 是一个 REST 对象，类似于 Pod。像是所有 REST 对象那样，用户可以 `POST` 一个 Service 的定义至 API 服务用于创建新的实例。Service 对象的名称必须是合法的 RFC 1035 标签名称。

例如一组 Pod，它们对外暴露了 9376 端口，同时还被打上 `app=MyApp` 标签：

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  selector:
    app.kubernetes.io/name: MyApp
  ports:
    - protocol: TCP
      port: 80
      targetPort: 9376
```

上述规范创建了一个新的名为 “my-service” 的 Service 对象，其代理 TCP 端口 9376 并且具有标签 `app=MyApp` 的 Pod 上。

k8s 为该服务分配一个 IP 地址（有时称为“集群 IP”），该 IP 地址由服务代理使用（详见下述 [VIP 和 Service 代理](@/docs/2022-9-1-k8s-notes-v.md#VirtualIPsAndServiceProxies)）。

Service 选择算符的控制器持续扫描匹配选择算符的 Pods，然后 POSTs 更新至一个名为“my-service”的端点对象。

{% blockquote_note() %}
一个 Service 可以将接收 port 映射到任意的 targetPort。默认情况下，targetPort 将被设置为与 port 字段相同的值。
{% end %}

Pods 中定义的 port 拥有名称，用户可以在 Service 的 `targetPort` 属性中引用这些名称。例如，用户可以如下绑定 Service 的 `targetPort` 给 Pod：

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
  labels:
    app.kubernetes.io/name: proxy
spec:
  containers:
    - name: nginx
      image: nginx:stable
      ports:
        - containerPort: 80
          name: http-web-svc

---
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  selector:
    app.kubernetes.io/name: proxy
  ports:
    - name: name-of-service-port
      protocol: TCP
      port: 80
      targetPort: http-web-svc
```

即使 Service 中使用同一配置名称混合使用多个 Pod，各 Pod 通过不同的端口号支持相同的网络协议，该功能同样适用。这为 Service 的部署和演化提供了很大的灵活性。例如用户可以在新版本中更改 Pod 中后端软件公开的端口号，而不会破坏客户端。

服务的默认协议是 TCP；用户还可以使用任何其他受支持的协议。

由于许多服务需要公开多个端口，因此 k8s 在服务对象上支持多个端口定义。每个端口定义可以具有相同的 `protocol`，也可以具有不同的协议。

#### 没有选择算符的 Service

因为选择算符的关系 Services 通常抽象了 k8s 的访问，但是当使用相关的端点对象同时没有选择算符时，Service 可以抽象其他类型的后端，包括运算在集群外的。例如：

- 用户希望在生产环境下拥有一个外部的数据库集群，但是在测试环境下使用自身的数据库。
- 用户希望 Service 指向另一个不同命名空间的 Service 或是在另一集群里的。
- 用户希望迁移工作负载至 k8s。当评估该方法时，仅在 k8s 中运行一部分后端。

任何这些场景，都能定义没有选择算符的 Service。例如

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  ports:
    - protocol: TCP
      port: 80
      targetPort: 9376
```

由于此服务没有选择算符，因此不会自动创建相应的端点对象。用户可以通过手动添加端点对象，将服务手动映射到运行该服务的网络地址和端口：

```yaml
apiVersion: v1
kind: Endpoints
metadata:
  # 这里的 name 要与 Service 的名字相同
  name: my-service
subsets:
  - addresses:
      - ip: 192.0.2.42
    ports:
      - port: 9376
```

Endpoints 对象的名称必须是合法的 DNS 子域名。

当用户为某 Service 创建一个端点对象时，用户需要将新对象的名称设置为与 Service 的名称相同。

#### 超出容量的 Endpoints

WIP

#### EndpointSlices

WIP

#### 应用协议

WIP

### 虚拟 IP 和 Service 代理 {#VirtualIPsAndServiceProxies}

在 k8s 集群中，每个节点运行一个 `kube-proxy` 进程。`kube-proxy` 负载为 Service 实现了一种 VIP（虚拟 IP）的形式，而不是 `ExternalName` 的形式。

#### 为什么不使用 DNS 轮询

有人会问为什么 k8s 依赖代理将入站流量转发到后端，使用其他方法呢？例如是否可以配置具有多个 A 值（或 IPv6 为 AAAA）的 DNS 记录，并依靠轮询名称解析？

使用服务代理有以下几个原因：

- DNS 实现的历史很久，它不遵守记录 TTL，并且在名称查找结构到期后对其进行缓存。
- 有些应用程序仅执行一次 DNS 查找，并无限期的缓存结果。
- 即使应用和库进行了适当的重新解析，DNS 记录上的 TTL 值低或为零也可能会给 DNS 带来高负载，从而使管理变得困难。

#### userspace 代理模式

WIP

#### iptables 代理模式

WIP

#### IPVS 代理模式

WIP

### 多端口 Service

有些服务用户需要公开多个端口。k8s 允许在 Service 对象上配置多个端口定义。为服务使用多个端口时，必须提供所有端口名称消除歧义。例如：

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  selector:
    app: MyApp
  ports:
    - name: http
      protocol: TCP
      port: 80
      targetPort: 9376
    - name: https
      protocol: TCP
      port: 443
      targetPort: 9377
```

{% blockquote_note() %}
与一般的 k8s 名称一样，端口名称只能包含小写字母数字字符和 `-`。端口名称还必须以字母数字字符开头和结尾。

例如，名称 `123-abc` 和 `web` 有效，但是 `123_abc` 和 `-web` 无效。
{% end %}

### 选择自己的 IP 地址

在 `Service` 创建的请求中，可以通过设置 `spec.clusterIP` 字段来指定自己的集群 IP 地址。比如，希望替换一个已经存在的 DNS 条目，或者遗留系统已经配置了一个固定的 IP 且很难重新配置。

用户选择的 IP 地址必须合法，并且这个 IP 地址在 `service-cluster-ip-range` CIDR 范围内，这对 API 服务器来说是通过一个标识来指定的。如果 IP 地址不合法，API 服务器会返回 HTTP 状态码 422，表示值不合法。

### 流量策略

#### 外部流量策略

WIP

#### 内部流量策略

WIP

### 服务发现

k8s 支持两种基本的服务发现模式 -- 环境变量和 DNS。

#### 环境变量

WIP

#### DNS

WIP

### 无头服务

WIP

### 发布服务

WIP

### 不足

WIP

### 虚拟 IP 实施

WIP

### API 对象

WIP

## Pod 与 Service 的 DNS

k8s 为 Service 和 Pod 创建 DNS 记录。用户可以使用一致的 DNS 名称而非 IP 地址访问 Service。

### 介绍 {#PodsAndDNSForServices-Introduction}

WIP

### Pods {#PodsAndDNSForServices-Pods}

WIP

## 使用服务连接到应用

### k8s 连接容器的模型

WIP

### 在集群中暴露 Pod

WIP

### 创建 Service

WIP

### 访问 Service

WIP

### 保护 Service

WIP

### 暴露 Service

WIP

## Ingress

**特性状态**：`v1.19 [stable]`

Ingress 时对集群中服务的外部访问进行管理的 API 对象，典型的访问方式是 HTTP。

Ingress 可以提供负载均衡，SSL 终结和基于名称的虚拟托管。

### 术语

WIP

### Ingress 是什么

WIP

### Ingress 资源

WIP

### 主机名通配符

WIP

### Ingress 类

WIP

### Ingress 类型

WIP

### 更新 Ingress

WIP

### 跨可用区失败

WIP

### 替代方案

WIP

## Ingress 控制器

WIP

## 端点切片

WIP

## 服务内部流量策略

WIP

## 拓扑感知提示

WIP

## 网络策略

WIP

## IPv4/IPv6 双协议栈

WIP
