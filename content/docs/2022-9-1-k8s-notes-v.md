+++
title="K8s 笔记 (V)"
description="服务，负载均衡和网络"
date=2022-09-01

draft = true

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

## 服务 Service {#ServicesLoadBalancingAndNetworking-Service}

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

### 发布服务（服务类型） {#Service-PublishingServices}

WIP

#### NodePort 类型 {#Service-PublishingServices-TypeNodePort}

WIP

#### LoadBalancer 类型 {#Service-PublishingServices-TypeLoadBalancer}

WIP

#### ExternalName 类型 {#Service-PublishingServices-TypeExternalName}

WIP

#### 外部 IP

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

k8s DNS 除了在集群上调度 DNS Pod 和 Service，同时也配置 kubelet 告知各个容器使用 DNS Service 的 IP 来解析 DNS 名称。

集群中定义的每个 Service（包括 DNS 服务器自身）都会被给予一个 DNS 名称。默认情况下，客户端 Pod 的 DNS 搜索列表会包含 Pod 自身的命名空间和集群的默认域。

#### Service 的命名空间

WIP

#### DNS 记录

WIP

#### Services {#PodsAndDNSForServices-Introduction-Services}

WIP

### Pods {#PodsAndDNSForServices-Pods}

WIP

## 使用服务连接到应用

### k8s 连接容器的模型

既然有了一个持续运行，可复制的应用，用户就可以将它暴露到网络上。

k8s 假设 Pod 可与其他 Pod 通信，无论它们在哪个主机上。k8s 给每个 Pod 分配一个集群私有 IP 地址，所以没必要再 Pod 与 Pod 之间创建连接或将容器的端口映射到主机端口。这以为着同一个 Pod 内的所有容器能通过 localhost 上的端口互相联通，集群中的所有 Pod 也不需要通过 NAT 转换就能够互相看到。

本指南使用一个简单的 Nginx 服务器来演示概念验证原型。

### 在集群中暴露 Pod

在之前的示例中已经试过了，但是现在以网络连接的视角在重做一遍。创建一个 Nginx Pod，注意其中包含一个容器端口的规约（`service/networking/run-my-nginx.yaml`）：

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-nginx
spec:
  selector:
    matchLabels:
      run: my-nginx
  replicas: 2
  template:
    metadata:
      labels:
        run: my-nginx
    spec:
      containers:
        - name: my-nginx
          image: nginx
          ports:
            - containerPort: 80
```

这使得可以从集群中任何一个节点来访问它。检查节点，该 Pod 正在运行：

```sh
kubectl apply -f ./run-my-nginx.yaml
kubectl get pods -l run=my-nginx -o wide
```

```txt
NAME                        READY     STATUS    RESTARTS   AGE       IP            NODE
my-nginx-3800858182-jr4a2   1/1       Running   0          13s       10.244.3.4    kubernetes-minion-905m
my-nginx-3800858182-kna2y   1/1       Running   0          13s       10.244.2.5    kubernetes-minion-ljyd
```

检查 Pod 的 IP 地址：

```sh
kubectl get pods -l run=my-nginx -o yaml | grep podIP
```

```txt
podIP: 10.244.3.4
podIP: 10.244.2.5
```

用户应该能够通过 ssh 登录到集群中的任何一个节点上，并使用 `curl` 等工具向着两个 IP 地址发出查询请求。值得注意的是，容器不会使用该节点上的 80 端口，也不会使用任何特定的 NAT 规则去路由流量到 Pod 上。这意味着可以在同一个节点上运行多个 Nginx Pod，使用相同的 `containerPort`，并且可以从集群中任何其他的 Pod 或节点上使用 IP 的方式访问它们。

### 创建 Service

现在有一组在一个扁平的，集群范围的地址空间中运行 Nginx 服务的 Pod。理论上，用户可以直接连接到这些 Pod，单如果某个节点死掉了会发生什么呢？Pod 会终止，Deployment 将创建新的 Pod，且使用不同的 IP。这正式 Service 要解决的问题。

k8s Service 是集群中提供相同功能的一组 Pod 的抽象表达。当每个 Service 创建时，会被分配一个唯一的 IP 地址（也称为 clusterIP）。这个 IP 地址与 Service 的生命周期绑定在一起，只要 Service 存在，它就不会改变。可以配置 Pod 使它与 Service 进行通信，Pod 知道与 Service 通信将被自动的负载均衡到该 Service 中的某些 Pod 上。

可以使用 `kubectl expose` 命令为 2 个 Nginx 副本创建一个 Service：

```sh
kubectl expose deployment/my-nginx
```

```txt
service/my-nginx exposed
```

这等价于使用 `kubectl create -f` 命令以及以下的 yaml 文件创建（`service/networking/nginx-svc.yaml`）：

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-nginx
  labels:
    run: my-nginx
spec:
  ports:
    - port: 80
      protocol: TCP
  selector:
    run: my-nginx
```

上述规约将创建一个 Service，其会将所有具有标签 `run: my-nginx` 的 Pod 的 TCP 80 端口暴露到一个抽象的 Service 端口上（`targetPort`：容器接收流量的端口；`port`：可任意取值的抽象的 Service 端口，其他 Pod 通过端口访问 Service）。查看 Service 资源：

```sh
kubectl get svc my-nginx
```

```txt
NAME       TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
my-nginx   ClusterIP   10.0.162.149   <none>        80/TCP    21s
```

如前面提到的，一个 Service 由一组 Pod 提供支撑。这些 Pod 通过 `endpoints` 暴露出来。Service Selector 将持续评估，结果被 POST 到一个名为 `my-nginx` 的端点对象上。当 Pod 终止后，它会自动从端点中移除，新的匹配上 Service Selector 的 Pod 将自动被添加到端点中。检查端点，注意到 IP 地址与在第一步创建的 Pod 是相同的。

```sh
kubectl describe svc my-nginx
```

```txt
Name:                my-nginx
Namespace:           default
Labels:              run=my-nginx
Annotations:         <none>
Selector:            run=my-nginx
Type:                ClusterIP
IP:                  10.0.162.149
Port:                <unset> 80/TCP
Endpoints:           10.244.2.5:80,10.244.3.4:80
Session Affinity:    None
Events:              <none>
```

```sh
kubectl get ep my-nginx
```

```txt
NAME       ENDPOINTS                     AGE
my-nginx   10.244.2.5:80,10.244.3.4:80   1m
```

现在用户应该可以从集群中任意节点上使用 curl 命令向 `<CLUSTER-IP>:<PORT>` 发送请求以访问 Nginx Service。注意 Service IP 完全是虚拟的，它从来没有走过网络，如果对它如何工作的原理好奇，可以进一步阅读[服务代理](@/docs/2022-9-1-k8s-notes-v.md#ServicesLoadBalancingAndNetworking-Service)的内容。

### 访问 Service

k8s 支持两种查找服务的主要模式：环境变量和 DNS。前者可以直接使用，后者需要 CoreDNS 集群插件。

{% blockquote_note() %}
如果不需要服务环境变量（因为可能与预期的程序冲突，可能要处理的变量太多，或者仅使用 DNS 等），则可以通过在 pod spec 上将 enableServiceLinks 标志设置为 false 来禁用此模式。
{% end %}

#### 环境变量 {#ConnectingApplicationsWithServices-AccessingTheService-EnvironmentVariables}

当 Pod 在节点上运行时，kubelet 会针对每个活跃的 Service 为 Pod 添加一组环境变量。这就引入了一个顺序的问题。为解释这个问题，先检查正在运行的 Nginx Pod 的环境变量（用户的环境中的 Pod 名称将会与下面示例命令中的不同）：

```sh
kubectl exec my-nginx-3800858182-jr4a2 -- printenv | grep SERVICE
```

```txt
KUBERNETES_SERVICE_HOST=10.0.0.1
KUBERNETES_SERVICE_PORT=443
KUBERNETES_SERVICE_PORT_HTTPS=443
```

能看到环境变量中并没有用户创建的 Service 相关的值。这时因为副本的创建先于 Service。这样做的另一个缺点是，调度器可能会将所有 Pod 部署到同一台机器上，若果该机器宕机则整个 Service 都会离线。要改正的话，我们可以先终止这两个 Pod，然后等待 Deployment 去重新创建它们。这次 Service 会*先于*副本存在。这将实现调度器级别的 Pod 按 Service 分布（假定所有的节点都具有相同的容量），并提供正确的环境变量：

```sh
kubectl scale deployment my-nginx --replicas=0; kubectl scale deployment my-nginx --replicas=2;

kubectl get pods -l run=my-nginx -o wide
```

```txt
NAME                        READY     STATUS    RESTARTS   AGE     IP            NODE
my-nginx-3800858182-e9ihh   1/1       Running   0          5s      10.244.2.7    kubernetes-minion-ljyd
my-nginx-3800858182-j4rm4   1/1       Running   0          5s      10.244.3.8    kubernetes-minion-905m
```

注意 Pod 具有不同的名称，这时因为它们是被重新创建的。

```sh
kubectl exec my-nginx-3800858182-e9ihh -- printenv | grep SERVICE
```

```txt
KUBERNETES_SERVICE_PORT=443
MY_NGINX_SERVICE_HOST=10.0.162.149
KUBERNETES_SERVICE_HOST=10.0.0.1
MY_NGINX_SERVICE_PORT=80
KUBERNETES_SERVICE_PORT_HTTPS=443
```

#### DNS {#ConnectingApplicationsWithServices-AccessingTheService-DNS}

k8s 提供了一个自动为其他 Service 分配 DNS 名字的 DNS 插件 Service。用户可以通过如下命令检查它是否在工作：

```sh
kubectl get services kube-dns --namespace=kube-system
```

```txt
NAME       TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)         AGE
kube-dns   ClusterIP   10.0.0.10    <none>        53/UDP,53/TCP   8m
```

本段剩余的内容假设用户已经拥有持久 IP 地址的 Service（my-nginx），以及一个为其 IP 分配名称的 DNS 服务器。这里使用 CoreDNS 集群插件（应用名为 `kube-dns`），所以在集群中的任何 Pod 中，用户都可以使用标准方法（如 `gethostbyname()`）与该 Service 通信。如果 CoreDNS 没有在运行，可以参照 CoreDNS README 或者安装 CoreDNS 来启动它。运行另一个 curl 应用来进行测试：

```sh
kubectl run curl --image=radial/busyboxplus:curl -i --tty
```

```txt
Waiting for pod default/curl-131556218-9fnch to be running, status is Pending, pod ready: false
Hit enter for command prompt
```

然后，按回车并执行命令 `nslookup my-nginx`：

```txt
[ root@curl-131556218-9fnch:/ ]$ nslookup my-nginx
Server:    10.0.0.10
Address 1: 10.0.0.10

Name:      my-nginx
Address 1: 10.0.162.149
```

### 保护 Service

到现在为止只在集群内部访问了 Nginx 服务器。在将 Service 暴露到因特网之前，希望确保通信信道是安全的。为了实现这个模板，需要：

- 用于 HTTPS 的自签名证书（除非已经用了一个身份证书）
- 使用证书配置的 Nginx 服务器
- 使 Pod 可以访问证书的 Secret

WIP

### 暴露 Service

WIP

## Ingress

**特性状态**：`v1.19 [stable]`

Ingress 时对集群中服务的外部访问进行管理的 API 对象，典型的访问方式是 HTTP。

Ingress 可以提供负载均衡，SSL 终结和基于名称的虚拟托管。

### 术语

为了表达更加清晰，定义以下术语：

- 节点（Node）：k8s 集群中的一台工作机器，是集群的一部分。
- 集群（Cluster）：一组运行由 k8s 管理的容器化应用程序的节点。在此示例和在大多数常见的 k8s 部署环境中，集群中的节点都不在公共网络中。
- 边缘路由器（Edge Router）：在集群中强制执行防火墙策略的路由器。可以是由云提供商管理的网关，也可以是物理硬件。
- 集群网络（Cluster Network）：一组逻辑的或物理的连接，根据 k8s 网络模型在集群内实现通信。
- 服务（Service）：k8s 服务（Service），使用标签选择器（selectors）辨认一组 Pod。除非另有说明，否则假定服务只具有在集群网络中可路由的虚拟 IP。

### Ingress 是什么

Ingress 公开从集群外部到集群内服务的 HTTP 和 HTTPS 路由。流量路由由 Ingress 资源上定义的规则控制。

下面是一个将所有流量都发送到同一 Service 的简单 Ingress 示例：

{{ image(src="/images/ingress.svg", alt="ingress") }}

Ingress 可为 Service 提供外部可访问的 URL、负载均衡流量、终止 SSL/TLS，以及基于名称的虚拟托管。Ingress 控制器通常负责通过负载均衡器来实现 Ingress，尽管它也可以配置边缘路由器或其他前端来帮助处理流量。

Ingress 不会公开任意端口或协议。将 HTTP 和 HTTPS 以外的服务公开到 Internet 时，通常使用 Service.Type=NodePort 或 Service.Type=LoadBalancer 类型的 Service。

### 环境准备

用户必须拥有一个 Ingress 控制器才能满足 Ingress 的要求。仅创建 Ingress 资源本身没有任何效果。

用户可能需要部署 Ingress 控制器，例如 ingress-nginx。可以从许多 Ingress 控制器中进行选择。

理想情况下，所有 Ingress 控制器都应符合参考规范。但是实际上不同的 Ingress 控制器操作略有不同。

{% blockquote_note()%}
确保查看了 Ingress 控制器的文档，以了解选择它的注意事项。
{% end %}

### Ingress 资源

一个最小的 Ingress 资源示例（`service/networking/minimal-ingress.yaml`）：

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: minimal-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx-example
  rules:
    - http:
        paths:
          - path: /testpath
            pathType: Prefix
            backend:
              service:
                name: test
                port:
                  number: 80
```

Ingress 需要指定 `apiVersion`，`kind`，`metadata` 和 `spec` 字段。Ingress 对象的命名必须是合法的 DNS 子域名名称。关于如何使用配置文件，请参见[部署应用](https://kubernetes.io/docs/tasks/run-application/run-stateless-application-deployment/)，[配置容器](https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/)与[资源管理](https://kubernetes.io/docs/concepts/cluster-administration/manage-deployment/)。Ingress 经常使用注解（annotations）来配置一些选项，具体取决于 Ingress 控制器，例如重写目标注解。不同的 Ingress 控制器支持不同的注解。查看所选的 Ingress 控制器文档，以了解其支持哪些注解。

Ingress 规约提供了配置负载均衡器或者代理服务器所需的所有信息。最重要的是，其中包含与所有传入请求匹配的规则列表。Ingress 资源仅支持用于转发 HTTP(S) 流量的规则。

如果 `ingressClassName` 被省略，那么用户应该定义一个默认 Ingress 类。

有一些 Ingress 控制器不需要定义默认的 `IngressClass`。比如：Ingress-NGINX 控制器可以通过参数 `--watch-ingress-without-class` 来配置。不过仍然推荐按下文所示来设置默认的 `IngressClass`。

#### Ingress 规则

每个 HTTP 规则都包含以下信息：

- 可选的 `host`。在此示例中，未指定 `host`，因此该规则适用于通过指定 IP 地址的入站 HTTP 通信。如果提供 `host`（例如 foo.bar.com），则 `rules` 适用于该 `host`。
- 路径列表 paths（例如 `/testpath`），每个路径都有一个由 `serviceName` 和 `servicePort` 定义的关联后端。在负载均衡器将流量定向到引用的服务之前，主机和路径都必须匹配传入请求的内容。
- `backend`（后端）是 Service 文档中所述的服务和端口名称的组合。与规则的 `host` 和 `path` 匹配的对 Ingress 的 HTTP(S) 请求将发送到列出的 `backend`。

通常在 Ingress 控制器中会配置 `defaultBackend`（默认后端），以服务于无法与规约中 `path` 匹配的所有请求。

#### 默认后端

没有设置规则的 Ingress 将所有流量发送到同一个默认后端，而 `.spec.defaultBackend` 则是在这种情况下处理请求的那个默认后端。`defaultBackend` 通常是 Ingress 控制器的匹配选项，而非在 Ingress 资源中指定。如果未设置任何的 `.spec.rules`，那么必须指定 `.spec.defaultBackend`。如果未设置 `defaultBackend`，那么如何处理所有与规则不匹配的流量将交由 Ingress 控制器决定（参考所选的 Ingress 控制器文档以了解它是如何处理那些流量的）。

如果没有 `hosts` 或 `paths` 与 Ingress 对象中的 HTTP 请求匹配，则流量将被路由到默认后端。

#### 资源后端

`Resource` 后端是一个引用，指向同一命名空间的另一个 k8s 资源，将其作为 Ingress 对象。`Resource` 后端与 Service 后端是互斥的，在二者均被设置时会无法通过合法性检查。`Resource` 后端的一种常见用法是将所有入站数据导向带有静态资产的对象存储后端。例如（`service/networking/ingress-resource-backend.yaml`）：

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-resource-backend
spec:
  defaultBackend:
    resource:
      apiGroup: k8s.example.com
      kind: StorageBucket
      name: static-assets
  rules:
    - http:
        paths:
          - path: /icons
            pathType: ImplementationSpecific
            backend:
              resource:
                apiGroup: k8s.example.com
                kind: StorageBucket
                name: icon-assets
```

创建了以上 Ingress 之后，用户可以使用下面的命令查看它：

```sh
kubectl describe ingress ingress-resource-backend
```

```txt
Name:             ingress-resource-backend
Namespace:        default
Address:
Default backend:  APIGroup: k8s.example.com, Kind: StorageBucket, Name: static-assets
Rules:
  Host        Path  Backends
  ----        ----  --------
  *
              /icons   APIGroup: k8s.example.com, Kind: StorageBucket, Name: icon-assets
Annotations:  <none>
Events:       <none>
```

#### 路径类型

Ingress 中的每个路径都需要有对应的路径类型（Path Type）。未明确设置 `pathType` 的路径无法通过合法性检查。当前支持的路径类型有三种：

- `ImplementationSpecific`：对于这种路径类型，匹配方法取决于 IngressClass。具体实现可以将其作为单独的 `pathType` 处理或者与 `Prefix` 或 `Exact` 类型作相同处理。
- `Exact`：精确匹配 URL 路径，且区分大小写。
- `Prefix`：基于以 `/` 分隔的 URL 路径前缀匹配。匹配区分大小写，并且对路径中的元素逐个完成。路径元素指的是由 `/` 分隔符分隔的路径中的标签列表。如果每个 p 都是请求路径 p 的元素前缀，则请求与路径 p 匹配。

{% blockquote_note() %}
如果路径的最后一个元素使请求路径中最后一个元素的子字符串，则不会匹配（例如：`/foo/bar` 匹配 `/foo/bar/baz`，但不匹配 `/foo/barbaz`）。
{% end %}

#### 示例 {#Ingress-TheIngressResource-Examples}

| 类型   | 路径                            | 请求路径        | 匹配与否？             |
| ------ | ------------------------------- | --------------- | ---------------------- |
| Prefix | `/`                             | （所有路径）    | 是                     |
| Exact  | `/foo`                          | `/foo`          | 是                     |
| Exact  | `/foo`                          | `/bar`          | 否                     |
| Exact  | `/foo`                          | `/foo/`         | 否                     |
| Exact  | `/foo/`                         | `/foo`          | 否                     |
| Prefix | `/foo`                          | `/foo`, `/foo/` | 是                     |
| Prefix | `/foo/`                         | `/foo`, `/foo/` | 是                     |
| Prefix | `/aaa/bb`                       | `/aaa/bbb`      | 否                     |
| Prefix | `/aaa/bbb`                      | `/aaa/bbb`      | 是                     |
| Prefix | `/aaa/bbb/`                     | `/aaa/bbb`      | 是，忽略尾部斜线       |
| Prefix | `/aaa/bbb`                      | `/aaa/bbb/`     | 是，匹配尾部斜线       |
| Prefix | `/aaa/bbb`                      | `/aaa/bbb/ccc`  | 是，匹配子路径         |
| Prefix | `/aaa/bbb`                      | `/aaa/bbbxyz`   | 否，字符串前缀不匹配   |
| Prefix | `/`, `/aaa`                     | `/aaa/ccc`      | 是，匹配 /aaa 前缀     |
| Prefix | `/`, `/aaa`, `/aaa/bbb`         | `/aaa/bbb`      | 是，匹配 /aaa/bbb 前缀 |
| Prefix | `/`, `/aaa`, `/aaa/bbb`         | `/ccc`          | 是，匹配 / 前缀        |
| Prefix | `/aaa`                          | `/ccc`          | 否，使用默认后端       |
| 混合   | `/foo (Prefix)`, `/foo (Exact)` | `/foo`          | 是，优选 Exact 类型    |

##### 多重匹配

在某些情况下，Ingress 中的多条路径会匹配同一个请求。这种情况下最长的匹配路径优先。如果仍然有两条同等的匹配路径，则精确路径类型优于前缀路径类型。

### 主机名通配符

| 主机        | host 头部         | 匹配与否？                          |
| ----------- | ----------------- | ----------------------------------- |
| `*.foo.com` | `bar.foo.com`     | 基于相同的后缀匹配                  |
| `*.foo.com` | `baz.bar.foo.com` | 不匹配，通配符仅覆盖了一个 DNS 标签 |
| `*.foo.com` | `foo.com`         | 不匹配，通配符仅覆盖了一个 DNS 标签 |

例如（`service/networking/ingress-wildcard-host.yaml`）：

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-wildcard-host
spec:
  rules:
    - host: "foo.bar.com"
      http:
        paths:
          - pathType: Prefix
            path: "/bar"
            backend:
              service:
                name: service1
                port:
                  number: 80
    - host: "*.foo.com"
      http:
        paths:
          - pathType: Prefix
            path: "/foo"
            backend:
              service:
                name: service2
                port:
                  number: 80
```

### Ingress 类

Ingress 可以由不同的控制器实现，通常使用不同的配置。每个 Ingress 应当指定一个类，也就是一个对 IngressClass 资源的引用。IngressClass 资源包含额外的配置，其中包括应当实现类的控制器名称。例如（`service/networking/external-lb.yaml`）：

```yaml
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: external-lb
spec:
  controller: example.com/ingress-controller
  parameters:
    apiGroup: k8s.example.com
    kind: IngressParameters
    name: external-lb
```

IngressClass 中的 `.spec.parameters` 字段可用于引用其他资源以提供额外的相关配置。

参数（`parameters`）的具体类型取决于用户在 `.spec.controller` 字段中指定的 Ingress 控制器。

#### IngressClass 的作用域

取决于用户的 Ingress 控制器，用户可能可以使用集群范围设置的参数或某个命名空间范围的参数。

##### 集群作用域

IngressClass 的参数默认是集群范围的。

如果设置了 `.spec.parameters` 字段且未设置 `.spec.parameters.scope` 字段，或是将 `.spec.parameters.scope` 字段设为 `Cluster`，那么该 IngressClass 所指代的即是一个集群作用域的资源。参数 `kind`（和 `apiGroup` 一起）指向一个集群作用域的 API（可能是一个定制资源 Custom Resource），而它的 `name` 则为此 API 确定了一个具体的集群作用域的资源。

示例：

```yaml
---
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: external-lb-1
spec:
  controller: example.com/ingress-controller
  parameters:
    # 此 IngressClass 的配置定义在一个名为 “external-config-1” 的
    # ClusterIngressParameter（API 组为 k8s.example.net）资源中。
    # 这项定义告诉 Kubernetes 去寻找一个集群作用域的参数资源。
    scope: Cluster
    apiGroup: k8s.example.net
    kind: ClusterIngressParameter
    name: external-config-1
```

##### 命名空间作用域

**特性状态**：`v1.23 [stable]`

如果用户设置了 `.spec.parameters` 字段且将 `.spec.parameters.scope` 字段设为了 `Namespace`，那么该 IngressClass 将会引用一个命名空间作用域的资源。`.spec.parameters.namespace` 必须和此资源所处的命名空间相同。

参数 `kind`（和 `apiGroup` 一起）指向一个命名空间作用域的 API（例如 ConfigMap），而它的 `name` 则确定了一个位于用户指定的命名空间中的具体资源。

命名空间作用域的参数帮助集群操作者将控制细分到用于工作负载的各种配置中（比如：负载均衡设置，API 网关定义）。如果用户使用集群作用域的参数，那么就必须从以下两项中选择一项执行：

- 每次修改配置，集群操作团队需要批准其他团队的修改。
- 集群操作团队定义具体的准入控制，比如 RBAC 角色与角色绑定，以使得应用程序团队可以修改集群作用域的配置参数资源。

IngressClass API 本身是集群作用域的。

以下是一个引用命名空间作用域的配置参数的 IngressClass 示例：

```yaml
---
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: external-lb-2
spec:
  controller: example.com/ingress-controller
  parameters:
    # 此 IngressClass 的配置定义在一个名为 “external-config” 的
    # IngressParameter（API 组为 k8s.example.com）资源中，
    # 该资源位于 “external-configuration” 命名空间中。
    scope: Namespace
    apiGroup: k8s.example.com
    kind: IngressParameter
    namespace: external-configuration
    name: external-config
```

#### 默认 Ingress 类

用户可以将一个特定的 IngressClass 标记为集群默认 Ingress 类。讲一个 IngressClass 资源的 `ingressclass.kubernetes.io/is-default-class` 注解设置为 `true` 将确保新的未指定 `ingressClassName` 字段的 Ingress 能够分配为这个默认的 IngressClass。

{% blockquote_warn%}
如果集群中又多个 IngressClass 被标记为默认，准入控制器将阻止创建新的未指定 `ingressClassName` 的 Ingress 对象。解决这个问题只需要确保集群中最多只能有一个 IngressClass 被标记为默认。
{% end %}

有一些 Ingress 控制器不需要定义默认的 `IngressClass`。比如 Ingress-NGINX 控制器可以通过参数 `--watch-ingress-without-class` 来配置。不过仍然推荐设置默认的 `IngressClass`。例如（`service/networking/default-ingressclass.yaml`）：

```yaml
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  labels:
    app.kubernetes.io/component: controller
  name: nginx-example
  annotations:
    ingressclass.kubernetes.io/is-default-class: "true"
spec:
  controller: k8s.io/ingress-nginx
```

### Ingress 类型 {#Ingress-TypesOfIngress}

#### 由单个 Service 来完成的 Ingress

现有的 k8s 概念允许用户暴露单个 Service（参见[代替方案](@/docs/2022-9-1-k8s-notes-v.md#Ingress-Alternatives)）。也可以通过指定无规则的*默认后端*来对 Ingress 进行此操作。例如（`service/networking/test-ingress.yaml`）：

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test-ingress
spec:
  defaultBackend:
    service:
      name: test
      port:
        number: 80
```

如果使用 `kubectl apply -f` 创建此 Ingress，则应该能够查看刚刚添加的 Ingress 的状态：

```sh
kubectl get ingress test-ingress
```

```txt
NAME           CLASS         HOSTS   ADDRESS         PORTS   AGE
test-ingress   external-lb   *       203.0.113.123   80      59s
```

其中 `203.0.113.123` 是由 Ingress 控制器分配以满足该 Ingress 的 IP。

{% blockquote_note() %}
入口控制器和负载平衡器可能需要一两分钟才能分配 IP 地址。在此之前，用户通常会看到地址字段的值被设定为 `<pending>`。
{% end %}

#### 简单扇出

一个扇出（fanout）配置根据请求的 HTTP URI 将来自同一 IP 地址的流量路由到多个 Service。Ingress 允许用户将负责均衡器的数量将至最低。例如这样的配置：

{{ image(src="/images/ingress-fanout.svg", alt="ingress fanout") }}

将需要一个如下所示的 Ingress（`service/networking/simple-fanout-example.yaml`）：

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: simple-fanout-example
spec:
  rules:
    - host: foo.bar.com
      http:
        paths:
          - path: /foo
            pathType: Prefix
            backend:
              service:
                name: service1
                port:
                  number: 4200
          - path: /bar
            pathType: Prefix
            backend:
              service:
                name: service2
                port:
                  number: 8080
```

当使用 `kubectl apply -f` 创建 Ingress 时：

```sh
kubectl describe ingress simple-fanout-example
```

```txt
Name:             simple-fanout-example
Namespace:        default
Address:          178.91.123.132
Default backend:  default-http-backend:80 (10.8.2.3:8080)
Rules:
  Host         Path  Backends
  ----         ----  --------
  foo.bar.com
               /foo   service1:4200 (10.8.0.90:4200)
               /bar   service2:8080 (10.8.0.91:8080)
Annotations:
  nginx.ingress.kubernetes.io/rewrite-target:  /
Events:
  Type     Reason  Age                From                     Message
  ----     ------  ----               ----                     -------
  Normal   ADD     22s                loadbalancer-controller  default/test
```

Ingress 控制器将提供实现特定的负载均衡器来满足 Ingress，只要 Service（`service1`，`service2`）存在。当它这样做时，用户会在 Address 字段看到负载均衡器的地址。

{% blockquote_note() %}
取决于用户所使用的 Ingress 控制器，用户可能需要创建默认 HTTP 后端服务。
{% end %}

#### 基于名称的虚拟托管

基于名称的虚拟主机支持将针对多个主机名的 HTTP 流量路由到同一 IP 地址上。

{{ image(src="/images/ingress-name-based.svg", alt="ingress name based") }}

以下 Ingress 让后台负载均衡器基于 host 头部字段来路由请求（`service/networking/name-virtual-host-ingress.yaml`）：

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: name-virtual-host-ingress
spec:
  rules:
    - host: foo.bar.com
      http:
        paths:
          - pathType: Prefix
            path: "/"
            backend:
              service:
                name: service1
                port:
                  number: 80
    - host: bar.foo.com
      http:
        paths:
          - pathType: Prefix
            path: "/"
            backend:
              service:
                name: service2
                port:
                  number: 80
```

如果用户创建的 Ingress 资源没有在 `rules` 中定义任何 `hosts`，则可以匹配指向 Ingress 控制器 IP 地址的任何网络流量，而无需基于名称的虚拟主机。

例如，以下 Ingress 会将请求 `first.bar.com` 的流量路由到 `service1`，将请求 `second.bar.com` 的流量路由到 `service2`，而所有其他流量都会被路由到 `service3`（`service/networking/name-virtual-host-ingress-no-third-host.yaml`）：

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: name-virtual-host-ingress-no-third-host
spec:
  rules:
    - host: first.bar.com
      http:
        paths:
          - pathType: Prefix
            path: "/"
            backend:
              service:
                name: service1
                port:
                  number: 80
    - host: second.bar.com
      http:
        paths:
          - pathType: Prefix
            path: "/"
            backend:
              service:
                name: service2
                port:
                  number: 80
    - http:
        paths:
          - pathType: Prefix
            path: "/"
            backend:
              service:
                name: service3
                port:
                  number: 80
```

#### TLS {#Ingress-TypesOfIngress-TLS}

WIP

#### 负载均衡 {#Ingress-TypesOfIngress-LoadBalancing}

Ingress 控制器启动引导时使用一些适用于所有 Ingress 的负载均衡策略设置，例如负载均衡算法，后端权重方案等。更高级的负载均衡概念（例如持久会话，动态权重）尚未通过 Ingress 公开。童虎可以通过用于服务的负责均衡器来获取这些功能。

值得注意的是，尽管健康检查不是通过 Ingress 直接暴露的，在 k8s 中存在并行的概念，比如就绪检查，允许用户实现相同的目的。请检查特定控制器的说明文档（nginx，GCE）以了解它们是怎样处理健康检查的。

### 更新 Ingress

要更新现有的 Ingress 以添加新的 Host，可以通过编辑资源来对其进行更新：

```sh
kubectl describe ingress test
```

```txt
Name:             test
Namespace:        default
Address:          178.91.123.132
Default backend:  default-http-backend:80 (10.8.2.3:8080)
Rules:
  Host         Path  Backends
  ----         ----  --------
  foo.bar.com
               /foo   service1:80 (10.8.0.90:80)
Annotations:
  nginx.ingress.kubernetes.io/rewrite-target:  /
Events:
  Type     Reason  Age                From                     Message
  ----     ------  ----               ----                     -------
  Normal   ADD     35s                loadbalancer-controller  default/test
```

通过以下命令打开编辑器，允许用户以 YAML 格式编辑现有配置。修改它来增加新的主机：

```yaml
spec:
  rules:
  - host: foo.bar.com
    http:
      paths:
      - backend:
          serviceName: service1
          servicePort: 80
        path: /foo
        pathType: Prefix
  - host: bar.baz.com
    http:
      paths:
      - backend:
          serviceName: service2
          servicePort: 80
        path: /foo
        pathType: Prefix
..
```

保存更改后，kubectl 将更新 API 服务器中的资源，该资源将告诉 Ingress 控制器重新配置负责均衡器，验证：

```sh
kubectl describe ingress test
```

```txt
Name:             test
Namespace:        default
Address:          178.91.123.132
Default backend:  default-http-backend:80 (10.8.2.3:8080)
Rules:
  Host         Path  Backends
  ----         ----  --------
  foo.bar.com
               /foo   service1:80 (10.8.0.90:80)
  bar.baz.com
               /foo   service2:80 (10.8.0.91:80)
Annotations:
  nginx.ingress.kubernetes.io/rewrite-target:  /
Events:
  Type     Reason  Age                From                     Message
  ----     ------  ----               ----                     -------
  Normal   ADD     45s                loadbalancer-controller  default/test
```

用户也可以通过 `kubectl replace -f` 命令调用修改后的 Ingress yaml 文件来获得同样的结果。

### 替代方案 {#Ingress-Alternatives}

- 使用 [Service.Type=LoadBalancer](@/docs/2022-9-1-k8s-notes-v.md#Service-PublishingServices-TypeLoadBalancer)
- 使用 [Service.Type=NodePort](@/docs/2022-9-1-k8s-notes-v.md#Service-PublishingServices-TypeNodePort)

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
