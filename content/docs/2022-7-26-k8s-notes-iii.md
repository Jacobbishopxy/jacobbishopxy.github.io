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

> **注意：**
>
> 在生产环境中部署容器应当避免使用 `:latest` 标签，因为这很难追踪哪个版本的镜像在运行，同时很难正确的进行回滚操作。
>
> 相反，应当指定一个有意义的标签例如 `v1.42.0`。

为了确保 Pod 总是使用同一个版本的容器镜像，用户可以指定镜像的摘要；替换 `<image-name>:<tag>` 为 `<image-name>@<digest>`（例如，`image@sha256:45b23dee08af5e43a7fea6c4cf9c25ccf269ee113168c19722f87876677c5cb2`）。

当使用镜像标签时，如果镜像仓库修改了代码所对应的镜像标签，可能会出现新旧代码混杂在 Pod 中运行的情况。镜像摘要唯一标识指定了镜像的版本，因此通过镜像名称和指定的摘要， k8s 在每次启动容器时都会运行同样的代码。通过摘要指定镜像可以固定运行的代码，这样镜像仓库的变化就不会导致版本的混乱。

有些三方的准入控制器在创建时会修改 Pods （以及 pod 模板），因此正在运行的负载是根据镜像摘要定义的，而不是标签。镜像仓库上的标签发生变化，用户都可以确保所有的工作负载都运行相同的代码，那么指定镜像摘要会很有用。

##### 默认镜像拉取策略

当用户（或者控制器）提交一个新的 Pod 至 API 服务，当满足指定条件时，集群会设置 `imagePullPolicy` 字段：

- 如果忽略 `imagePullPolicy` 字段，容器镜像的标签是 `:latest`，`imagePullPolicy` 则会被自动设置为 `Always`；

- 如果忽略 `imagePullPolicy` 字段，同时不指定容器镜像的标签，`imagePullPolicy` 则会被自动设置为 `Always`；

- 如果忽略 `imagePullPolicy` 字段，同时指定容器镜像的标签不为 `:latest`，`imagePullPolicy` 则会被自动设置为 `IfNotPresent`。

> **注意：**
>
> 容器 `imagePullPolicy` 的值总是在对象初次*创建*时被设置，而在之后镜像标签改变时不会被更新。
>
> 例如，如果用户创建一个带有标签不为 `:latest` 镜像的 Deployment，之后更新 Deployment 的镜像标签为 `:latest`，`imagePullPolicy` 字段*不会*改为 `Always`。在初始化创建后，用户需要手动修改所有对象的拉取策略。

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
<!-- ### 使用案例 -->

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

## 容器生命周期钩子
