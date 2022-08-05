+++
title="K8s 笔记 (VI)"
description="存储"
date=2022-09-15

[taxonomies]
categories = ["Doc"]
tags = ["k8s"]

[extra]
toc = true
+++

## 卷 Volumes

容器中的磁盘文件是临时的，这会给运行在容器里的重要应用程序带来一些问题。其中一个问题就是当容器崩溃时文件会丢失。另外在 `Pod` 中的容器间共享文件时也会出现问题。k8s 的卷 volume 抽象解决了这些问题。

### 背景

Docker 里也有卷的概念，尽管它是松散并少量管理的。Docker 卷是磁盘上或者另外一个容器内的一个目录。Docker 提供卷驱动程序，但是其功能非常有限。

k8s 提供很多类型的卷。Pod 可以同时使用任意数量的卷类型。临时卷拥有与 pod 一致的生命周期，但是持久卷能存活超过 pod。当 pod 终止时，k8s 摧毁临时卷；而持久卷则不会被摧毁。对于 Pod 中任何类型的卷，在容器重启期间数据都不会丢失。

卷的核心是一个目录，有可能包含了一些数据，可以被 pod 中的容器访问的。目录是如何形成的，使用何种介质保存数据，以及其内容，都是由使用的卷类型所决定的。

使用卷时，在 `.spec.volumes` 字段中设置为 Pod 提供的卷，并在 `.spec.containers[*].volumeMounts` 字段中声明卷在容器中的挂载位置。容器中的进程看到的文件系统视图是由他们的容器镜像的初始内容以及挂载在容器中的卷（如果定义了）所组成的。其中根文件系统和容器镜像的内容吻合。任何在该文件系统下的写入操作，如果被允许，都会影响接下来容器中进程访问文件系统时所看到的内容。

卷挂载在镜像中的指定路径下。Pod 配置中的每个容器必须独立指定各个卷的挂载位置。

卷不能挂载到其他卷之上（存在使用 subPath 的相关机制），也不能与其他卷有硬链接。

### 卷类型

k8s 支持下列类型的卷（已忽略弃用与不使用的）：

#### configMap

configMap 提供一种注入配置数据进入 pods 的方式。存储在 ConfigMap 中的数据可以被在一个 `configMap` 的卷中被引用，并 pod 中被容器化的应用消费。

当引用一个 ConfigMap，用户需要在卷中提供其名称。可以自定义路径来使用指定的 ConfigMap 入口。下面配置展示了如何挂载 `log-config` 的 ConfigMap 至一个名为 `configmap-pod` 的 Pod 上：

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: configmap-pod
spec:
  containers:
    - name: test
      image: busybox:1.28
      volumeMounts:
        - name: config-vol
          mountPath: /etc/config
  volumes:
    - name: config-vol
      configMap:
        name: log-config
        items:
          - key: log_level
            path: log_level
```

`log-config` 这个 ConfigMap 被挂载为一个卷，其存储在入口 `log_level` 的所有内容被挂载进 Pod 的 `/etc/config/log_level` 路径上。注意这个路径是来源于卷的 `mountPath` 和 `path` 键的 `log_level`。

{% blockquote_note() %}
用户必须在使用前创建 ConfigMap。
容器使用 ConfigMap 作为 `subPath` 卷挂载不会接收到 ConfigMap 的更新。
文件形式的文本数据使用 UTF-8 编码。其它的字符编码则使用 `binaryData`。
{% end %}

#### downwardAPI

`downwardAPI` 卷使得 downward API 数据对应用程序可用。这种卷类型挂载一个目录并在纯文本文件中写入请求数据。

{% blockquote_note() %}
容器使用 downward API 以 `subPath` 卷挂载时，不会接收到字段的更新。
{% end %}

#### emptyDir

当一个 Pod 被分配 到一个节点时，`emptyDir` 卷首次被创建，并且只要该 Pod 运行在节点上，卷就一直存在。正如名称所示，`emptyDir` 卷开始是空的。Pod 中所有的容器可以读写 `emptyDir` 中同样的文件，即使卷可以被挂载在容器里同样或者不同的路径上。无论什么原因 Pod 从节点上被移除时，`emptyDir` 的数据都会被永久删除。

{% blockquote_note() %}
容器崩溃并不会从节点上移除 Pod。`emptyDir` 卷中的数据在容器崩溃时是安全的。
{% end %}

`emptyDir` 的一些用法：

- 缓存空间，例如基于磁盘的归并排序。
- 为耗时较长的计算任务提供检查点，以便任务能方便的从崩溃前状态恢复执行。
- 在 Web 服务器容器服务数据时，保存内容管理器容器获取的文件。

根据用户环境的不同，`empty` 卷存储在什么介质上是根据节点决定的，例如磁盘或 SSD，或网络存储。然而如果用户设置 `emptyDir.medium` 字段为 `"Memory"`，k8s 会挂载一个 tmpfs（基于 RAM 的文件系统）。虽然 tmpfs 非常快，但是要注意不像磁盘，tmpfs 会在节点重启时被清除，并且用户写入的所有文件都会计入容器的内存消耗，因此会受到容器内存限制的约束。

{% blockquote_note() %}
如果 `SizeMemoryBackedVolumes` 特性门控开启，用户可以基于内存提供的卷指定大小。如果未指定大小，则基于内存的卷的大小为 Linux 主机上内存的 50%。
{% end %}

例如：

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: test-pd
spec:
  containers:
    - image: k8s.gcr.io/test-webserver
      name: test-container
      volumeMounts:
        - mountPath: /cache
          name: cache-volume
  volumes:
    - name: cache-volume
      emptyDir: {}
```

#### hostPath

{% blockquote_alert() %}
HostPath 卷存在很多安全风险，最佳做法是尽可能的避免使用 HostPath。当必须使用时，它的范围仅限于所需的文件或目录，并以制度方式挂载。

如果通过 AdmissionPolicy 限制 HostPath 对特定目录的访问，则必须要求 `volumeMounts` 使用 `readOnly` 挂载使策略生效。
{% end %}

`hostPath` 从主机节点的文件系统卷挂载一个文件或文件夹到 Pod 中。大部分 Pods 是不需要这样做的，但是这样为一些应用程序提供了强大的逃生舱。

例如 `hostPath` 的一些用法：

- 运行一个需要访问 Docker 内部机制的容器；可使用 `hostPath` 挂载 `/var/lib/docker` 路径。
- 在容器中运行 cAdvisor 时，以 `hostPath` 方式挂载 `/sys`。
- 允许 Pod 指定给定的 `hostPath` 在运行 Pod 之前是否应该存在，是否应该创建以及应该以什么方式存在。

#### local

`local` 卷表示一个挂载的本地存储设备例如磁盘，分区或者路径。

本地卷只能被用于静态的创建持久化卷，是不支持动态制备的。

相比与 `hostPath` 卷，`local` 卷能够以持久和可移植的方式使用，无需手动将 Pod 调度到该点。系统通过查看 PersistentVolume 节点亲和性配置就能了解卷的节电约束。

然而 `local` 卷仍然取决于底层节点的可用性，并不适合所有应用程序。如果节点变得不健康，那么 `local` 卷也将变得不可被 Pod 访问。那么使用该卷的 Pod 将不能运行。使用 `local` 卷的应用程序必须能够容忍这种可用性的降低，以及因底层磁盘的耐用性特征而带来的潜在的数据丢失风险。

下面是一个使用 `local` 卷和 `nodeAffinity` 的持久卷示例：

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: example-pv
spec:
  capacity:
    storage: 100Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: local-storage
  local:
    path: /mnt/disks/ssd1
  nodeAffinity:
    required:
      nodeSelectorTerms:
        - matchExpressions:
            - key: kubernetes.io/hostname
              operator: In
              values:
                - example-node
```

用户使用 `local` 卷时需要设置 PersistentVolume 的 `nodeAffinity` 字段。k8s 调度器使用该字段来调度 Pods 到正确的节点。

PersistentVolume 的 `volumeMode` 可以被设置为 “Block”（而不是默认值“Filesystem”）作为原始块设备来暴露出来。

使用本地卷时，更加推荐的做法是创建一个 `volumeBindingMode` 字段设置为 `WaitForFirstConsumer` 的存储类 StorageClass。延迟卷绑定的操作可以保证 k8s 在为 PersistentVolume 做出绑定决策时，评估 Pod 可能具有的其它节点约束，例如节点字段需求，节点选择器，Pod 亲和性和 Pod 反亲和性。

用户可以在 k8s 之外单独运行静态驱动更改本地卷的生命周期管理。请注意，此驱动不支持动态配置。

{% blockquote_note() %}
如果不使用外部静态驱动来管理卷的生命周期，用户需要手动清理和删除 local 类型的持久卷。
{% end %}

#### projected

投射卷能将若干现有的卷来源映射到同一目录上。

### 使用 subPath

有时候在单个 Pod 中共享卷给多方使用是很有用的。`volumeMounts.subPath` 属性可用于指定所引用的卷内的子路径，而不是其跟路径。

下面的例子展示了如何配置一个带有 LAMP 栈（Linux Apache MySQL PHP）的 Pod 使用一个单独的，共享的卷。这个例子的 `subPath` 配置不推荐在生产环境中使用。

PHP 应用的代码与资产映射到卷的 `html` 文件夹，MySQL 数据库存储于卷的 `mysql` 文件夹。例如：

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-lamp-site
spec:
  containers:
    - name: mysql
      image: mysql
      env:
        - name: MYSQL_ROOT_PASSWORD
          value: "rootpasswd"
      volumeMounts:
        - mountPath: /var/lib/mysql
          name: site-data
          subPath: mysql
    - name: php
      image: php:7.0-apache
      volumeMounts:
        - mountPath: /var/www/html
          name: site-data
          subPath: html
  volumes:
    - name: site-data
      persistentVolumeClaim:
        claimName: my-lamp-site-data
```

#### 使用带有扩展环境变量的 subPath

**特性状态**：`v1.17 [stable]`

从 downward API 环境变量中，使用 `subPathExpr` 字段构建 `subPath` 路径名。`subPath` 与 `subPathExpr` 属性是互斥的。

这个示例中，Pod 使用 `subPathExpr` 来 hostPath 卷 `/var/log/pods` 中创建目录 `pod1`。`hostPath` 卷采用来自 `downwardAPI` 的 Pod 名称生成目录名。宿主目录 `/var/log/pods/pod1` 被挂载到容器的 `/logs` 中。

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod1
spec:
  containers:
    - name: container1
      env:
        - name: POD_NAME
          valueFrom:
            fieldRef:
              apiVersion: v1
              fieldPath: metadata.name
      image: busybox:1.28
      command:
        [
          "sh",
          "-c",
          "while [ true ]; do echo 'Hello'; sleep 10; done | tee -a /logs/hello.txt",
        ]
      volumeMounts:
        - name: workdir1
          mountPath: /logs
          # The variable expansion uses round brackets (not curly brackets).
          subPathExpr: $(POD_NAME)
  restartPolicy: Never
  volumes:
    - name: workdir1
      hostPath:
        path: /var/log/pods
```

### 资源

`emptyDir` 卷的存储介质（磁盘、SSD 等）是由保存 kubelet 数据的根目录（通常为 `/var/lib/kubelet`）的文件系统的介质来确定的。 k8s 对 `emptyDir` 卷或者 `hostPath` 卷可以消耗的空间没有限制，容器之间或 Pod 之间也没有隔离。

### 树外卷插件

WIP

### 挂载卷的传播

WIP

## 持久卷 Persistent Volumes

WIP

## 投射卷 Projected Volumes

WIP

## 临时卷 Ephemeral Volumes

WIP

## 存储类 Storage Classes

WIP

## 动态卷制备 Dynamic Volume Provisioning

WIP

## 卷快照 Volume Snapshots

WIP

## 卷快照类 Volume Snapshot Classes

WIP

## CSI 卷克隆 CSI Volume Cloning

WIP

## 存储容量 Storage Capacity

WIP

## 节点特定卷限制 Node-specific Volume Limits

WIP

## 卷健康监测 Volume Health Monitoring

WIP
