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

### 介绍

存储的管理是一个与计算实例的管理完全不同的问题。PersistentVolume 子系统为用户和管理员提供了一组 API，将存储如何制备的细节从其如何被使用中抽象出来。为了实现这点，引入了两个新的 API 资源：PersistentVolume 和 PersistentVolumeClaim。

**持久卷（PersistentVolume，PV）**是集群中的一块存储，可以由管理员实现制备，或者使用存储类（Storage Class）来动态制备。持久卷是集群资源，就像节点也是集群资源一样。PV 持久卷和普通 Volume 一样，也是使用卷插件来实现的，知识它们拥有独立于任何使用 PV 的 Pod 的生命周期。此 API 对象中记载了存储的实现细节，无论其背后是 NFS，iSCSI 还是特定于云平台的存储系统。

**持久卷申领（PersistentVolumeClaim，PVC）**表达的是用户对存储的请求。概念上与 Pod 类似。Pod 会消耗节点资源，而 PVC 申领会消耗 PV 资源。Pod 可以请求特定数量的资源（CPU 和内存）；同样 PVC 申领也可以请求特定的大小的访问模式（如，可以要求 PV 卷能够以 ReadWriteOnce，ReadOnlyMany 或 ReadWriteMany 模式之一来挂载，详见访问模式）。

尽管 PersistentVolumeClaim 允许用户消耗抽象的存储资源，常见的情况是针对不同的问题用户需要的是具有不同属性（比如性能）的 PersistentVolume 卷。集群管理员需要能够提供不同性质的 PersistentVolume，并且这些 PV 卷之间的差别不仅限于卷大小和访问模式，同时又不能将卷是如何实现的这些细节暴露给用户。为了满足这种需求，就有了**存储类（StorageClass）**资源。

### 卷和申领的生命周期

PV 卷是集群中的资源。PVC 申领是对这些资源的请求，也被用来执行对资源的申领检查。PV 卷和 PVC 申领之前的互动遵循以下生命周期

#### 制备 Provisioning

PV 的制备有两种方式：静态制备或动态制备。

- 静态制备

  集群管理员创建若干 PV。这些卷对象带有真是存储的细节信息，并且对集群用户可用（可见）。PV 对象存在于 k8s API 中，可供用户消费（使用）。

- 动态制备

  如果管理员所创建的所有静态 PV 都无法与用户的 PersistentVolumeClaim 匹配，集群可以尝试为该 PVC 动态制备一个存储卷。该制备操作是基于 StorageClass 来实现的：PVC 必须请求某个存储类，同时集群管理员必须已经创建并配置了该类，这样动态制备卷的动作才会发生。如果 PVC 指定存储类为 `""`，则相当于为自身禁止使用动态制备的卷。

  为了基于存储类完成动态的存储制备，集群管理员需要在 API 服务器上启用 `DefaultStorageClass` 准入控制器。举例，可以通过保证 `DefaultStorageClass` 出现在 API 服务器组件的 `--enable-admission-plugins` 标志值中实现这点；该标志的值可以是逗号分隔的有序列表。

#### 绑定 Binding

用户创建一个带有特定存储内容和特定访问模式需求的 PersistentVolumeClaim 对象；在动态制备场景下，这个 PVC 对象可能已经创建完毕。主控节点中的控制回路检测新的 PVC 对象，寻找与之匹配的 PV（如果可能得话），并将两者绑定到一起。如果为了新的 PVC 动态制备了 PV，则控制回路总是将该 PV 绑定到这一 PVC。否则，用户总是能够获得它们所请求的资源，只是所获得的 PV 可能会超出所请求的配置。一旦绑定关系建立，则 PersistentVolumeClaim 绑定就是排他性的，无论该 PVC 是如何与 PV 建立的绑定关系。PVC 和 PV 之间的绑定是一种一对一的映射，实现上使用 ClaimRef 来记录 PV 与 PVC 之间的双向绑定关心。

如果找不到匹配的 PV，PVC 会无限期的处于未绑定状态。当与之匹配的 PV 可用时，PVC 会被绑定。例如，即使某集群上制备了很多 50G 大小的 PV，也无法与请求 100 G 大小的存储的 PVC 匹配。当新的 100G PV 被加入到集群时，该 PVC 才有可能被绑定。

#### 使用 Using

Pod 将 PVC 当做存储卷来使用。集群会检查 PVC，找到所绑定的卷，并为 Pod 挂载该卷。对于支持多种访问模式的卷，用户要在 Pod 中以卷的形式使用申领时指定期望的访问模式。

一旦用户有了申领对象并且该申领已经被绑定，则所绑定的 PV 在用户仍然需要它期间一直属于该用户。用户通过在 Pod 的 `volumes` 块中包含 `persistentVolumeClaim` 节区来调度 Pod，访问所申领的 PV。细节可参阅[使用申领作为卷](@/docs/2022-9-15-k8s-notes-vi.md#PersistentVolumes-ClaimsAsVolumes)。

#### 保护使用中的存储对象

保护使用中的存储对象（Storage Object in Use Protection）这一功能特性的目的是确保仍被 Pod 使用的 PersistentVolumeClaim 对象及其所绑定的 PersistentVolume 对象在系统中不会被删除，因为这样做可能会引起数据丢失。

{% blockquote_note() %}
当使用某 PVC 的 Pod 对象仍然存在时，认为该 PVC 仍被此 Pod 使用。
{% end %}

如果用户删除被某 Pod 使用的 PVC 对象，该 PVC 不会被立刻删除。PVC 对象的移除会被推迟，直至其不再被任何 Pod 使用。此外，如果管理员删除已绑定到某 PVC 的 PV，该 PV 也不会立刻移除。PV 对象的移除也要推迟到该 PV 不再绑定到 PVC。

可以看到当 PVC 状态为 `Terminating` 且其 `Finalizers` 列表中包含 `kubernetes.io/pvc-protection` 时，PVC 对象时处于被保护状态的。

```sh
kubectl describe pvc hostpath
```

```txt
Name:          hostpath
Namespace:     default
StorageClass:  example-hostpath
Status:        Terminating
Volume:
Labels:        <none>
Annotations:   volume.beta.kubernetes.io/storage-class=example-hostpath
               volume.beta.kubernetes.io/storage-provisioner=example.com/hostpath
Finalizers:    [kubernetes.io/pvc-protection]
...
```

也可以看到当 PV 对象的状态为 `Terminating` 且其 `Finalizers` 列表中包含 `kubernetes.io/pv-protection` 时，PV 对象时处于被保护状态的。

```sh
kubectl describe pv task-pv-volume
```

```txt
Name:            task-pv-volume
Labels:          type=local
Annotations:     <none>
Finalizers:      [kubernetes.io/pv-protection]
StorageClass:    standard
Status:          Terminating
Claim:
Reclaim Policy:  Delete
Access Modes:    RWO
Capacity:        1Gi
Message:
Source:
    Type:          HostPath (bare host directory volume)
    Path:          /tmp/data
    HostPathType:
Events:            <none>
```

#### 回收 Reclaiming

当用户不再使用其存储卷时，可以从 API 中将 PVC 对象删除，从而允许该资源被回收再利用。PersistentVolume 对象的回收策略告诉集群，当其被从申领中释放时如何处理该数据卷。目前，数据卷可以被保留，回收或删除。

##### 保留 Retain

回收策略 `Retain` 使得用户可以手动回收资源。当 PersistentVolumeClaim 对象被删除时，PersistentVolume 卷仍然存在，对应的数据卷被视为“已释放 released”。由于卷上仍然存在在这前一申领人的数据，该卷还不能用于其他申领。管理员可以通过下面的步骤来手动回收该卷：

1. 删除 PersistentVolume 对象。与之相关的，位于外部基础设施中的存储资产（例如 AWS EBS，GCE PD，Azure Disk 或 Cinder 卷）在 PV 删除之后仍然存在。
1. 根据情况，手动清除所关联的存储资产上的数据。
1. 手动删除所关联的存储资产。

如果希望重用该存储资产，可以基于存储资产的定义创建新的 PersistentVolume 卷对象。

##### 删除 Delete

对于支持 `Delete` 回收策略的卷插件，删除动作会将 PersistentVolume 对象从 k8s 中移除，同时也会从外部基础设施（如 AWS EBS，GCE PD，Azure Disk 或 Cinder 卷）中移除所关联的存储资产。动态制备的卷会继承其 StorageClass 中设置的回收策略，该策略默认为 `Delete`。管理员需要根据用户的期望来配置 StorageClass；否则 PV 被创建之后必须要被编辑或者修补。

#### PersistentVolume 删除保护 finalizer

WIP

#### 预留 PersistentVolume

WIP

#### 扩充 PVC

WIP

### 持久卷的类型

WIP

### 持久卷

WIP

### PersistentVolumeClaims

WIP

### 使用申领作为卷 {#PersistentVolumes-ClaimsAsVolumes}

WIP

### 原始块卷支持

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
