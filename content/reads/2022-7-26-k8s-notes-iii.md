+++
title="K8s 笔记 (III)"
description="容器"
date=2022-07-26

[taxonomies]
categories = ["Doc"]
tags = ["k8s"]

[extra]
toc = true
+++

## 简介

每个运行的容器都是可重复的；包含依赖环境在内的标准意味着无论你在哪里运行它都会得到相同的行为。

容器将引用程序从底层的主机设施中解耦。这使得在不同的云或者 OS 环境中部署更加容易。

容器镜像是一个随时可以运行的软件包，包含运行引用程序的一切：代码以及其所需的所有运行时，应用程序和系统库，以及一些基本设置的默认值。

在设计上，容器是不可变的：你不能更改已经运行的容器的代码。如果有一个容器化的应用程序需要修改，则需要构建包含更改的新镜像，然后基于新镜像重新运行容器

容器运行时是扶着运行容器的软件。k8s 支持很多容器运行时，例如 Docker，containerd，CRI-O 以及 k8s CRI（容器运行环境接口）的其他任何实现。

## 镜像

容器镜像代表封装了应用程序以及其所有的软件依赖的二进制数据。容器镜像是可以独立运行的可执行软件包，同时其所处的运行时环境具有良好状况的假设。

用户通常创建一个容器镜像接着上传至仓库 Registry，然后在 Pod 中引用它。

### 镜像名称

容器镜像通常会命名类似于 `pause`，`example/mycontainer` 或 `kube-apiserver`。镜像可以包含仓库的主机名称；例如：`fictional.registry.example/imagename`，也可以添加端口；例如：`fictional.registry.example:10443/imagename`。

如果用户不指定仓库主机名称，k8s 会假设使用的是 Docker 公有仓库。

在镜像名称后用户可以添加一个*标记*（等同于使用 `docker` 或 `podman` 命令）。标签让用户鉴别同一个镜像的不同版本。

镜像标签由大小写字母，数字，下划线（`_`），点（`.`）以及杠（`-`）组成。另外，可以放置分隔符（`_`，`-` 和 `.`）于镜像标签内。如果不指定标签，k8s 会认为是 `latest`。

### 更新镜像

当第一次创建一个 Deployment，StatefulSet，Pod 或者其他包含临时 Pod 模版的对象时，如果不显式指定时，在 pod 中所有容器默认的拉取策略会被设置为 `IfNotPresent`。这个策略会导致 kubelet 拉取时跳过已有的镜像。

#### 镜像拉取策略

容器的 `imagePullPolicy` 以及镜像标签会影响 kubelet 尝试拉取（下载）指定镜像。

可以为 `imagePullPolicy` 设置以下的变量：

- `IfNotPresent`：镜像只会在本地不存在时拉取

- `Always`：每次 kubelet 启动容器时，kubelet 查询容器镜像仓库，将名称解析为一个镜像摘要 image digest。如果 kubelet 有一个容器镜像，并且对应的摘要已在本地缓存，kubelet 就会使用其缓存的镜像；否则，kubelet 就会使用解析后的摘要拉取镜像，并使用该镜像来启动容器。

- `Never`：kubelet 不会尝试拉取镜像。如果镜像已经以某种方式存在本地，kubelet 会尝试启动容器；否则，会启动失败。

底层镜像提供者的缓存语义可以使 `imagePullPolicy: Always` 高效，只要仓库能可靠的访问仓库。容器运行时可以观察到镜像层已经存在在节点上，这样就不需要再次下载。

{% blockquote_note() %}
在生产环境中部署容器应当避免使用 `:latest` 标签，因为这很难追踪哪个版本的镜像在运行，同时很难正确的进行回滚操作。

相反，应当指定一个有意义的标签例如 `v1.42.0`。
{% end %}

为了确保 Pod 总是使用同一个版本的容器镜像，用户可以指定镜像的摘要；替换 `<image-name>:<tag>` 为 `<image-name>@<digest>`（例如，`image@sha256:45b23dee08af5e43a7fea6c4cf9c25ccf269ee113168c19722f87876677c5cb2`）。

当使用镜像标签时，如果镜像仓库修改了代码所对应的镜像标签，可能会出现新旧代码混杂在 Pod 中运行的情况。镜像摘要唯一标识指定了镜像的版本，因此通过镜像名称和指定的摘要， k8s 在每次启动容器时都会运行同样的代码。通过摘要指定镜像可以固定运行的代码，这样镜像仓库的变化就不会导致版本的混乱。

有些三方的准入控制器在创建时会修改 Pods （以及 pod 模板），因此正在运行的负载是根据镜像摘要定义的，而不是标签。镜像仓库上的标签发生变化，用户都可以确保所有的工作负载都运行相同的代码，那么指定镜像摘要会很有用。

##### 默认镜像拉取策略

当用户（或者控制器）提交一个新的 Pod 至 API 服务，当满足指定条件时，集群会设置 `imagePullPolicy` 字段：

- 如果忽略 `imagePullPolicy` 字段，容器镜像的标签是 `:latest`，`imagePullPolicy` 则会被自动设置为 `Always`；

- 如果忽略 `imagePullPolicy` 字段，同时不指定容器镜像的标签，`imagePullPolicy` 则会被自动设置为 `Always`；

- 如果忽略 `imagePullPolicy` 字段，同时指定容器镜像的标签不为 `:latest`，`imagePullPolicy` 则会被自动设置为 `IfNotPresent`。

{% blockquote_note() %}
容器 `imagePullPolicy` 的值总是在对象初次*创建*时被设置，而在之后镜像标签改变时不会被更新。

例如，如果用户创建一个带有标签不为 `:latest` 镜像的 Deployment，之后更新 Deployment 的镜像标签为 `:latest`，`imagePullPolicy` 字段*不会*改为 `Always`。在初始化创建后，用户需要手动修改所有对象的拉取策略。
{% end %}

##### 必要的镜像拉取

如果每次都强制拉取，用户可以采用以下一种方式：

- 设置容器的 `imagePullPolicy` 为 `Always`。

- 忽略 `imagePullPolicy` 并使用 `:latest` 作为镜像的标签；在提交 Pod 时，k8s 将会设置策略为 `Always`。

- 忽略 `imagePullPolicy` 以及镜像使用的标签；在提交 Pod 时， k8s 将会设置策略为 `Always`。

- 开启 AlwaysPullImages 的准入控制器。

#### ImagePullBackOff

当 kubelet 使用容器运行时创建 Pod 时，容器可能因为 `ImagePullBackOff` 导致状态为 Waiting。

`ImagePullBackOff` 状态意味着容器无法启动，因为 k8s 无法拉取容器镜像（可能是包含无效的镜像名称，或者从私有仓库拉取而没有 `imagePullSecret`）。`BackOff` 部分标识 k8s 将继续尝试拉取镜像，并增加回退延迟。

k8s 会增加每次尝试之间的延迟，直到达到变异限制，即 300 秒（5 分钟）。

### 带镜像索引的多架构镜像

在提供二进制镜像的同时，容器仓库也可以服务于容器镜像的索引。镜像索引可以根据特定于体系结构版本的容器指向若干镜像清单 image manifests。这里的关键点在于用户可以拥有一个镜像的名称并且允许不同的系统根据它们使用的机器架构来获取正确的二进制镜像

k8s 自身通常在命名容器镜像时添加后缀 `~$(ARCH)`。为了向前兼容，请在生成较老的镜像时也提供后缀。这里的关键点是为某镜像（如 `pause`）生成针对所有平台都是用的清单时，生成 `pause-amd64` 这类镜像，使得较老的配置文件或者将镜像后缀硬编码到其中的 YAML 文件也可以兼容。

### 使用私有仓库

对于读取私有仓库的镜像可能需要钥匙，可以由以下几种方式做认证：

- 配置节点的私有仓库鉴权
  - 所有 pods 可以读取任何配置过的私有仓库
  - 需要通过集群管理者进行节点配置
- 预拉取镜像
  - 所有 pods 可以使用在节点缓存的任意镜像
  - 需要通过根访问所有节点进行设置
- 在 Pod 上指定 ImagePullSecrets
  - 只有当提供了自身要是的 pods 可以访问私有仓库
- 特定厂商或本地扩展
  - 如果在使用定制的节点配置，用户（或云平台提供商）可以实现让节点向容器仓库认证的机制

<!-- #### 配置节点的私有库认证 -->
<!-- #### config.json 说明 -->
<!-- #### 预拉取的镜像 -->
<!-- #### Pod 上指定 ImagePullSecrets -->

## 容器环境

k8s 容器环境提供了多种中药的资源给容器：

- 文件系统，结合了镜像以及若干 volumes
- 容器本身的信息
- 其它集群中对象的信息

### 容器信息

容器的*主机名称*就是在容器中运行的 Pod 的名称。可以通过 `hostname` 命令或者调用 libc 中的 `gethostname` 函数来获取名称。

Pod 名称以及命名空间可以作为环境变量通过 [downward API](https://kubernetes.io/docs/tasks/inject-data-application/downward-api-volume-expose-pod-information/) 来获取。

用户在 Pod 上定义的环境变量同样可用于容器，它们也是容器镜像中被指定的静态环境变量。

### 集群信息

当一个容器被创建时，所有运行服务的列表可用作该容器的环境变量。这里的服务仅限于新容器的 Pod 所在的命名空间中的服务，以及 k8s 控制面的服务。

一个名为*foo*的服务映射到名为*bar*的容器时，以下变量则会被定义：

```txt
FOO_SERVICE_HOST=<the host the service is running on>
FOO_SERVICE_PORT=<the port the service is running on>
```

服务具有专用的 IP 地址。如果启用了 DNS 插件， 可以在容器中通过 DNS 来访问服务。

## 运行时类

**特性状态**：`v1.20 [stable]`

运行时类 RuntimeClass 是一个用于选择容器运行配置的特性。容器运行配置则用于运行 Pod 的容器。

### 动机

用户可以为不同的 Pods 设置不同的 RuntimeClass 提供性能与安全之间的平衡。例如，如果一部分的工作负载需要高等级的信息安全保障，用户可能需要选择调度这些 Pods 使它们运行在硬件虚拟化的容器运行时。这样用户将从这些不同运行时所提供的额外隔离中获益，代价是一些额外的开销。

用户还可以使用 RuntimeClass 运行具有相同容器运行时但具有不同设置的 Pod。

### 设置

1. 在节点上配置 CRI 实现

1. 创建相关的 RuntimeClass 资源

## 容器生命周期回调

### 概述

类似于许多具有生命周期回调组件的编程语言框架，例如 Angular，k8s 为容器提供了生命周期回调。回调使得容器能够了解其管理生命周期中的事件，并在执行相应的生命周期回调时运行在处理程序中实现的代码。

### 容器回调

有两个回调暴露给容器：

`PostStart`：这个回调在容器被创建之后立即被执行。但是不能保证回调会在容器入口点（Entrypoint）之前执行。没有参数传递给处理程序。

`PreStop`：在容器因为 API 请求或者管理事件（例如存活探针，启动探针失败，资源抢占，资源竞争等）而被终止之前，此回调会被调用。如果容器已经处理已终止或者完成状态，则对 preStop 回调的调用将失败。在用来停止容器的 TERM 信号被发出之前，回调必须执行结束。Pod 的终止期限在 `PreStop` 回调被执行之前开始计数，所以无论回调函数的执行结果如何，容器最终都会在 Pod 终止期限内被终止。没有参数会被传递给处理程序。

#### 回调处理程序的实现

容器可以通过实现和注册该回调的处理程序来访问该回调。针对容器，有两种类型的回调处理程序可供实现：

- Exec - 在容器的 cgroups 和名字空间中执行特定的命令（例如 `pre-stop.sh`）。命令所消耗的资源计入容器的资源消耗。
- HTTP - 对容器上的特定端点执行 HTTP 请求。

#### 回调处理程序执行

当调用容器生命周期管理回调时，k8s 管理系统根据回调动作执行其处理程序，`httpGet` 和 `tcpSocket` 在 kubelet 进程执行，而 `exec` 则由容器内执行。

回调处理程序调用在包含容器的 Pod 上下文中是同步的。这意味着对于 `PostStart` 回调，容器入口点和回调异步触发。但是，如果回调运行或挂起的时间太长，则容器无法达到 `running` 状态。

`PreStop` 回调并不会与停止容器的信号处理程序异步执行；回调必须在可以发送信号之前完成执行。如果 `PreStop` 回调在执行期间停滞不前，Pod 的阶段会变成 `Terminating` 并且一直处于该状态，直到其 `terminationGracePeriodSeconds` 耗尽为止，这时 Pod 会被杀死。这一宽限期是针对 `PreStop` 回调的执行时间及容器正常停止时间的总和而言的。例如如果 `terminationGracePeriodSeconds` 是 60，回调函数换了 55 秒完成执行，而容器在收到信号后花了 10 秒来正常结束，那么容器会在其能够正常结束之前即被杀死，因为 `terminationGracePeriodSeconds` 的值小于后面两件事情所花费的总时间（55 + 10）。

如果 `PostStart` 或 `PreStop` 回调失败，则会杀死容器。

用户应该使他们的回调处理程序尽可能的轻量级。但也需要考虑长时间运行的命令也很有用的情况，比如在停止容器之前保存状态。

#### 回调递送保证

回调的递送应该是**至少一次**，这意味着对于任何给定的事件，例如 `PostStart` 或 `PreStop`，回调可以被调用多次。如何正确处理被多次调用的情况，是回调实现所需要考虑的问题。

通常情况下，只会进行单次递送。例如，如果 HTTP 回调接收器宕机，无法接受流量，则不会尝试重新发送。然而偶尔也会发生重复递送的可能。例如 kubelet 在发送回调的过程中重新启动，回调可能会在 kubelet 回复后重新发送。

#### 调试回调处理程序

回调处理程序的日志不会在 Pod 事件中公开。如果处理程序由于某种原因失败，它将播放一个事件。对于 `PostStart`，这是 `FailedPostStartHook` 事件，对于 `PreStop`，这是 `FailedPreStopHook` 事件。要自己生成失败的 `FailedPreStopHook` 事件，请修改 lifecycle-events.yaml 文件将 postStart 命令改为 "badcommand" 并应用它。以下是通过运行 `kubectl describe pod lifecycle-demo` 后你看到的一些结果事件的示例输出：

```txt
Events:
  Type     Reason               Age              From               Message
  ----     ------               ----             ----               -------
  Normal   Scheduled            7s               default-scheduler  Successfully assigned default/lifecycle-demo to ip-XXX-XXX-XX-XX.us-east-2...
  Normal   Pulled               6s               kubelet            Successfully pulled image "nginx" in 229.604315ms
  Normal   Pulling              4s (x2 over 6s)  kubelet            Pulling image "nginx"
  Normal   Created              4s (x2 over 5s)  kubelet            Created container lifecycle-demo-container
  Normal   Started              4s (x2 over 5s)  kubelet            Started container lifecycle-demo-container
  Warning  FailedPostStartHook  4s (x2 over 5s)  kubelet            Exec lifecycle hook ([badcommand]) for Container "lifecycle-demo-container" in Pod "lifecycle-demo_default(30229739-9651-4e5a-9a32-a8f1688862db)" failed - error: command 'badcommand' exited with 126: , message: "OCI runtime exec failed: exec failed: container_linux.go:380: starting container process caused: exec: \"badcommand\": executable file not found in $PATH: unknown\r\n"
  Normal   Killing              4s (x2 over 5s)  kubelet            FailedPostStartHook
  Normal   Pulled               4s               kubelet            Successfully pulled image "nginx" in 215.66395ms
  Warning  BackOff              2s (x2 over 3s)  kubelet            Back-off restarting failed container
```
