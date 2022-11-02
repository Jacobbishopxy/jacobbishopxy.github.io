+++
title="K8s 笔记 (VI)"
description="存储"
date=2022-09-15

[taxonomies]
categories = ["Read"]
tags = ["k8s"]

[extra]
toc = true
+++

## 卷 Volumes {#Volumes}

容器中的磁盘文件是临时的，这会给运行在容器里的重要应用程序带来一些问题。其中一个问题就是当容器崩溃时文件会丢失。另外在 `Pod` 中的容器间共享文件时也会出现问题。k8s 的卷 volume 抽象解决了这些问题。

### 背景 {#Volumes-Background}

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

### 资源 {#Volume-Resource}

`emptyDir` 卷的存储介质（磁盘、SSD 等）是由保存 kubelet 数据的根目录（通常为 `/var/lib/kubelet`）的文件系统的介质来确定的。 k8s 对 `emptyDir` 卷或者 `hostPath` 卷可以消耗的空间没有限制，容器之间或 Pod 之间也没有隔离。

### 树外卷插件

WIP

### 挂载卷的传播

WIP

## 持久卷 Persistent Volumes {#PersistentVolumes}

### 介绍 {#PersistentVolumes-Introduction}

存储的管理是一个与计算实例的管理完全不同的问题。PersistentVolume 子系统为用户和管理员提供了一组 API，将存储如何制备的细节从其如何被使用中抽象出来。为了实现这点，引入了两个新的 API 资源：PersistentVolume 和 PersistentVolumeClaim。

**持久卷（PersistentVolume，PV）**是集群中的一块存储，可以由管理员实现制备，或者使用存储类（Storage Class）来动态制备。持久卷是集群资源，就像节点也是集群资源一样。PV 持久卷和普通 Volume 一样，也是使用卷插件来实现的，知识它们拥有独立于任何使用 PV 的 Pod 的生命周期。此 API 对象中记载了存储的实现细节，无论其背后是 NFS，iSCSI 还是特定于云平台的存储系统。

**持久卷申领（PersistentVolumeClaim，PVC）**表达的是用户对存储的请求。概念上与 Pod 类似。Pod 会消耗节点资源，而 PVC 会消耗 PV 资源。Pod 可以请求特定数量的资源（CPU 和内存）；同样 PVC 也可以请求特定的大小的访问模式（如，可以要求 PV 能够以 ReadWriteOnce，ReadOnlyMany 或 ReadWriteMany 模式之一来挂载，详见访问模式）。

尽管 PersistentVolumeClaim 允许用户消耗抽象的存储资源，常见的情况是针对不同的问题用户需要的是具有不同属性（比如性能）的 PersistentVolume 卷。集群管理员需要能够提供不同性质的 PersistentVolume，并且这些 之间的差别不仅限于卷大小和访问模式，同时又不能将卷是如何实现的这些细节暴露给用户。为了满足这种需求，就有了**存储类（StorageClass）**资源。

### 卷和申领的生命周期

PV 是集群中的资源。PVC 是对这些资源的请求，也被用来执行对资源的申领检查。PV 和 PVC 之前的互动遵循以下生命周期

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

一旦用户有了申领对象并且该申领已经被绑定，则所绑定的 PV 在用户仍然需要它期间一直属于该用户。用户通过在 Pod 的 `volumes` 块中包含 `persistentVolumeClaim` 节区来调度 Pod，访问所申领的 PV。细节可参阅[使用申领作为卷](@/reads/2022-9-15-k8s-notes-vi.md#PersistentVolumes-ClaimsAsVolumes)。

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

**特性状态**：`v1.23 [alpha]`

可以在 PersistentVolume 上添加终结器 Finalizer，用于确保只有在删除对应的存储后才删除具有 `Delete` 回收策略的 PersistentVolume。

新引入的 `kubernetes.io/pv-controller` 和 `external-provisioner.volume.kubernetes.io/finalizer` 终结器仅会被添加到动态制备的卷上。

终结器 `kubernetes.io/pv-controller` 会被添加到树内插件卷上。例：

```txt
kubectl describe pv pvc-74a498d6-3929-47e8-8c02-078c1ece4d78
Name:            pvc-74a498d6-3929-47e8-8c02-078c1ece4d78
Labels:          <none>
Annotations:     kubernetes.io/createdby: vsphere-volume-dynamic-provisioner
                 pv.kubernetes.io/bound-by-controller: yes
                 pv.kubernetes.io/provisioned-by: kubernetes.io/vsphere-volume
Finalizers:      [kubernetes.io/pv-protection kubernetes.io/pv-controller]
StorageClass:    vcp-sc
Status:          Bound
Claim:           default/vcp-pvc-1
Reclaim Policy:  Delete
Access Modes:    RWO
VolumeMode:      Filesystem
Capacity:        1Gi
Node Affinity:   <none>
Message:
Source:
    Type:               vSphereVolume (a Persistent Disk resource in vSphere)
    VolumePath:         [vsanDatastore] d49c4a62-166f-ce12-c464-020077ba5d46/kubernetes-dynamic-pvc-74a498d6-3929-47e8-8c02-078c1ece4d78.vmdk
    FSType:             ext4
    StoragePolicyName:  vSAN Default Storage Policy
Events:                 <none>
```

终结器 `external-provisioner.volume.kubernetes.io/finalizer` 会被添加到 CSI 卷上。例：

```txt
Name:            pvc-2f0bab97-85a8-4552-8044-eb8be45cf48d
Labels:          <none>
Annotations:     pv.kubernetes.io/provisioned-by: csi.vsphere.vmware.com
Finalizers:      [kubernetes.io/pv-protection external-provisioner.volume.kubernetes.io/finalizer]
StorageClass:    fast
Status:          Bound
Claim:           demo-app/nginx-logs
Reclaim Policy:  Delete
Access Modes:    RWO
VolumeMode:      Filesystem
Capacity:        200Mi
Node Affinity:   <none>
Message:
Source:
    Type:              CSI (a Container Storage Interface (CSI) volume source)
    Driver:            csi.vsphere.vmware.com
    FSType:            ext4
    VolumeHandle:      44830fa8-79b4-406b-8b58-621ba25353fd
    ReadOnly:          false
    VolumeAttributes:      storage.kubernetes.io/csiProvisionerIdentity=1648442357185-8081-csi.vsphere.vmware.com
                           type=vSphere CNS Block Volume
Events:                <none>
```

为特定的树内卷插件启用 `CSIMigration` 特性将删除 `kubernetes.io/pv-controller` 终结器， 同时添加 `external-provisioner.volume.kubernetes.io/finalizer` 终结器。 同样，禁用 `CSIMigration` 将删除 `external-provisioner.volume.kubernetes.io/finalizer` 终结器， 同时添加 `kubernetes.io/pv-controller` 终结器。

#### 预留 PersistentVolume

通过在 PersistentVolumeClaim 中指定 PersistentVolume，可以什么该特定 PV 与 PVC 之间的绑定关系。如果该 PV 存在且未被通过其 `claimRef` 字段预留给 PVC，则该 PV 会和该 PVC 绑定到一起。

绑定操作不会考虑某些卷匹配条件是否满足，包括节点亲和性等。控制面仍然会检查存储类，访问模式和所请求的存储尺寸都是合法的。

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: foo-pvc
  namespace: foo
spec:
  storageClassName: "" # 此处须显式设置空字符串，否则会被设置为默认的 StorageClass
  volumeName: foo-pv
  ...
```

此方法无法对 PV 的绑定特权做出任何形式的保证。如果有其它 PVC 可以使用用户所指定的 PV，则用户应该首先预留该 PV。用户可以将 PV 的 `claimRef` 字段设置为相关的 PVC 以确保其它 PVC 不会绑定到该 PV。

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: foo-pv
spec:
  storageClassName: ""
  claimRef:
    name: foo-pvc
    namespace: foo
  ...
```

如果用户想用 `claimPolicy` 属性设置为 `Retain` 的 PV 时，包括希望复用现有的 PV 时，这点很有用。

#### 扩充 PVC

**特性状态**：`v1.11 [beta]`

WIP

### 持久卷的类型

PV 持久卷是用插件的形式来实现的。Kubernetes 目前支持以下插件：

- awsElasticBlockStore - AWS 弹性块存储（EBS）
- azureDisk - Azure Disk
- azureFile - Azure File
- cephfs - CephFS volume
- csi - 容器存储接口 (CSI)
- fc - Fibre Channel (FC) 存储
- gcePersistentDisk - GCE 持久化盘
- glusterfs - Glusterfs 卷
- hostPath - HostPath 卷 （仅供单节点测试使用；不适用于多节点集群；请尝试使用 local 卷作为替代）
- iscsi - iSCSI (SCSI over IP) 存储
- local - 节点上挂载的本地存储设备
- nfs - 网络文件系统 (NFS) 存储
- portworxVolume - Portworx 卷
- rbd - Rados 块设备 (RBD) 卷
- vsphereVolume - vSphere VMDK 卷

### 持久卷 {#PersistentVolume-PersistentVolume}

每个 PV 对象都包含 `spec` 和 `status` 部分，分别对应卷的规约和状态。PersistentVolume 对象的名称必须是合法的 DNS 子域。

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv0003
spec:
  capacity:
    storage: 5Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Recycle
  storageClassName: slow
  mountOptions:
    - hard
    - nfsvers=4.1
  nfs:
    path: /tmp
    server: 172.17.0.2
```

{% blockquote_note() %}
在集群中使用持久卷存储通常需要一些特定于具体卷类型的辅助程序。上述例子中，PV 是 NFS 类型的，因此需要辅助程序 `/sbin/mount.nfs` 来支持挂载 NFS 文件系统。
{% end %}

#### 容量

一般而言，每个 PV 都有确定的存储容量。容量属性是使用 PV 对象的 `capacity` 属性来设置的。参考词汇表中的[量纲 Quantity](https://kubernetes.io/docs/reference/glossary/?all=true#term-quantity)词条了解 `capacity` 字段可以接受的单位。

目前，存储大小是可以设置和请求的唯一资源。未来可能会包含 IOPS，吞吐量等属性。

#### 卷模式 {#PersistentVolume-PersistentVolume-VolumeMode}

**特性状态**：`v1.18 [stable]`

针对 PV，k8s 支持两种卷模式 volumeModes：文件系统 Filesystem 和 块 Block。`volumeMode` 是一个可选的 API 参数。如果该参数被省略，默认的卷模式是 `Filesystem`。

`volumeMode` 属性设置为 `Filesystem` 的卷会被 Pod **挂载 Mount**到某个目录。如果卷的存储来自某块设备而该设备目前为空，k8s 会在第一次挂载卷之前在设备上创建文件系统。

用户可以将 `volumeMode` 设置为 `Block`，以便将卷作为原始块设备来使用。这类卷以块的方式交给 Pod 使用，其上没有任何文件系统。这种模式对于为 Pod 提供一种使用最快可能方式来访问卷而言很有帮助，Pod 和卷之间不存在文件系统层。另外 Pod 中运行的应用必须知道如何处理原始块设备。关于如何在 Pod 中使用 `volumeMode: Block` 的卷，可参阅[原始块卷支持](@/reads/2022-9-15-k8s-notes-vi.md#PersistentVolumes-RawBlockVolumeSupport)。

#### 访问模式 {#PersistentVolume-PersistentVolume-AccessMode}

PV 可以用资源提供者所支持的任何方式挂载到宿主系统上。如下所示，提供者（驱动）的能力不同，每个 PV 的访问模式都会设置为对应卷所支持的模式值。例如，NFS 可以支持多个读写客户，但是某个特定的 NFS PV 可能在服务器上只读的方式导出。每个 PV 都会获得自身的访问模式集合，描述的是特定 PV 的能力。

{% styled_block(class="color-beige font-bold") %}
ReadWriteOnce
{% end %}
卷可以被一个节点以读写方式挂载。ReadWriteOnce 访问模式也运行运行在同一节点上的多个 Pod 访问卷。

{% styled_block(class="color-beige font-bold") %}
ReadOnlyMany
{% end %}
卷可以被多个节点以制度方式挂载。

{% styled_block(class="color-beige font-bold") %}
ReadWriteOnceMany
{% end %}
卷可以被多个节点以读写方式挂载。

{% styled_block(class="color-beige font-bold") %}
ReadWriteOncePod
{% end %}
卷可以被单个 Pod 以读写方式挂载。如果想确保整个集群中只有一个 Pod 可以读取或写入该 PVC，请使用 ReadWriteOncePod 访问模式。这只支持 CSI 卷以及需要 k8s 1.22 以上版本。

在命令行接口 CLI 中，访问模式一颗使用一下缩写模式：

- ROX - ReadWriteOnce
- ROX - ReadOnlyMany
- RWX - ReadWriteMany
- RWOP - ReadWriteOncePod

{% blockquote_note() %}
k8s 使用卷访问模式来匹配 PVC 和 PV。在某些场合下，卷访问模式也会限制 PV 可以挂载的位置。卷访问模式并**不会**在存储已经被挂载的情况下为其实施写保护。即使访问模式设置为 ReadWriteOnce，ReadOnlyMany 或 ReadWriteMany 它们也不会对卷形成限制。例如，即使某个卷创建时设置为 ReadOnlyMany，也无法保证该卷是只读的。如果访问模式设置为 ReadWriteOncePod，则卷会被限制起来并且只能挂载到一个 Pod 上。
{% end %}

{% blockquote_warn() %}
每个卷同一时刻只能以一种访问模式挂载，即使该卷能够支持多种访问模式。例如，一个 GCEPersistentDisk 卷可以被某节点以 ReadWriteOnce 模式挂载，或者被多个节点以 ReadOnlyMany 模式挂载，但不可以同时以两种模式挂载。
{% end %}

#### 类 {#PersistentVolume-PersistentVolume-Class}

每个 PV 可以属于某个类 Class，通过将其 `storageClassName` 属性设置为某个 StorageClass 的名称来指定。特定类的 PV 只能绑定到请求该类存储卷的 PVC。未设置 `storageClassName` 的 PV 没有类设定，只能绑定到那些没有指定特定存储类的 PVC。

#### 阶段 {#PersistentVolume-PersistentVolume-Phase}

每个卷会处于一下阶段 Phase 之一：

- Available 可用 -- 卷是一个空闲资源，尚未绑定到任何申领；
- Bound 已绑定 -- 该卷以及绑定到某申领；
- Released 已释放 -- 所绑定的申领已被删除，但是资源尚未被集群回收；
- Failed 失败 -- 卷的自动回收操作失败。

### PVC {#PersistentVolume-PersistentVolumeClaims}

每个 PVC 对象都有 `spec` 和 `status` 部分，分别对应申领的规约和状态。PVC 对象的名称必须是合法的 DNS 子域名。

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: myclaim
spec:
  accessModes:
    - ReadWriteOnce
  volumeMode: Filesystem
  resources:
    requests:
      storage: 8Gi
  storageClassName: slow
  selector:
    matchLabels:
      release: "stable"
    matchExpressions:
      - { key: environment, operator: In, values: [dev] }
```

#### 访问模式 {#PersistentVolume-PersistentVolumeClaims-AccessMode}

申领在请求具有特定访问模式的存储时，使用与卷相同的[访问模式约定](@/reads/2022-9-15-k8s-notes-vi.md#PersistentVolume-PersistentVolume-AccessMode)。

#### 卷模式 {#PersistentVolume-PersistentVolumeClaims-VolumeMode}

申领使用与[卷相同的约定](@/reads/2022-9-15-k8s-notes-vi.md#PersistentVolume-PersistentVolume-VolumeMode)来表明是将卷作为文件系统还是块设备来使用。

#### 资源 {#PersistentVolume-PersistentVolumeClaims-Resources}

申领和 Pod 一样，也可以请求特定数量的资源。在这个上下文中，请求的资源是存储。卷和申领都是用相同的[资源模型](https://github.com/kubernetes/design-proposals-archive/blob/main/scheduling/resources.md)。

#### 选择算符 {#PersistentVolume-PersistentVolumeClaims-Selector}

申领可以设置[标签选择算符](@/reads/2022-7-10-k8s-notes-i.md#Objects-LabelsAndSelectors)来进一步过滤卷集合。只有标签与选择算符想匹配的卷能够绑定到申领上。选择算符包含两个字段：

- `matchLabels` - 卷必须包含带有此值的标签
- `matchExpressions` - 通过设定键 key，值列表和操作符 operator 来构造需求。合法的操作符有 In，NotIn，Exists 和 DoesNotExist。

来自 `matchLabels` 和 `matchExpressions` 的所有需求都按逻辑与的方式组合在一起。这些需求都必须被满足才被视为匹配。

#### 类 {#PersistentVolume-PersistentVolumeClaims-Class}

申领可以通过为 `storageClassName` 属性设置 StorageClass 的名称来请求特定的存储类。只有所请求的类的 PV，即 `storageClassName` 值与 PVC 设置相同的 PV，才能绑定到 PVC。

PVC 不比一定要请求某个类。如果 PVC 的 `storageClassName` 属性值设置为 `""`，则被视为要请求的是没有设置存储类的 PV，因此这一 PVC 只能绑定到未设置存储类的 PV（未设置注解或者注解值为 `""` 的 PV 对象在系统中不会被删除，因为这样做可能会引起数据丢失）。未设置 `storageClassName` 的 PVC 与此大不相同，也会被集群作不同处理。具体筛查方式取决于 `DefaultStorageClass` [准入控制插件](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/#defaultstorageclass)是否被启用。

- 如果准入控制器插件被启用，则管理员可以设置一个默认的 StorageClass。所有未设置 `storageClassName` 的 PVC 创建的处理方式与未启用准入控制器插件时相同。如果设定的默认存储类不止一个，准入控制插件会禁止所有创建 PVC 操作。
- 如果准入控制器插件被关闭，则不存在默认 StorageClass 的说法。所有未设置 `storageClassName` 的 PVC 都只能绑定到未设置存储类的 PV。在这种情况下，未设置 `storageClassName` 的 PVC 与 `storageClassName` 设置为 `""` 的 PVC 的处理方式相同。

取决于安装方式，默认的 StorageClass 可能在集群安装期间由插件管理器（Addon Manager）部署到集群中。

当某 PVC 除了请求 StorageClass 之外还设置了 `selector`，则这两种需求会按逻辑与关系处理：已有隶属于所请求类切带有所请求标签的 PV 才能绑定到 PVC。

{% blockquote_note() %}
目前，设置了非空 `selector` 的 PVC 对象无法让集群为其动态制备 PV 卷。
{% end %}

### 使用申领作为卷 {#PersistentVolumes-ClaimsAsVolumes}

Pod 将申领作为卷来使用，并以此访问存储资源。申领必须位于使用它的 Pod 所在的同一名字空间内。集群在 Pod 的名字空间中查找申领，并使用它来获得申领所使用的 PV。之后，卷会被挂载到宿主上并挂载到 Pod 中。

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: mypod
spec:
  containers:
    - name: myfrontend
      image: nginx
      volumeMounts:
        - mountPath: "/var/www/html"
          name: mypd
  volumes:
    - name: mypd
      persistentVolumeClaim:
        claimName: myclaim
```

### 原始块卷支持 {#PersistentVolumes-RawBlockVolumeSupport}

**特性状态**：`v1.18 [stable]`

以下卷插件支持原始块卷，包括其动态制备（如果支持的话）的卷：

- AWSElasticBlockStore
- AzureDisk
- CSI
- FC （光纤通道）
- GCEPersistentDisk
- iSCSI
- Local 卷
- OpenStack Cinder
- RBD （Ceph 块设备）
- VsphereVolume

#### 使用原始块卷的持久卷

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: block-pv
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  volumeMode: Block
  persistentVolumeReclaimPolicy: Retain
  fc:
    targetWWNs: ["50060e801049cfd1"]
    lun: 0
    readOnly: false
```

#### 申请原始块的 PVC

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: block-pvc
spec:
  accessModes:
    - ReadWriteOnce
  volumeMode: Block
  resources:
    requests:
      storage: 10Gi
```

#### 在容器中添加原始块设备路径的 Pod 规约

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-with-block-volume
spec:
  containers:
    - name: fc-container
      image: fedora:26
      command: ["/bin/sh", "-c"]
      args: ["tail -f /dev/null"]
      volumeDevices:
        - name: data
          devicePath: /dev/xvda
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: block-pvc
```

{% blockquote_note() %}
向 Pod 中添加原始块设备时，要在容器内设置设备路径而不是挂载路径。
{% end %}

#### 绑定块卷

如果用户通过 PVC 规约的 `volumeMode` 字段来表明对原始块设备的请求，绑定规则与之前版本中未在规约中考虑此模式的实现略有不同。下面列举的表格是用户和管理员可以为请求原始块设备所作设置的组合。此表格表明在不同的组合下卷是否会被绑定。

静态制备卷的卷绑定矩阵：

| PV         | volumeMode | PVC volumeMode Result |
| ---------- | ---------- | --------------------- |
| 未指定     | 未指定     | 绑定                  |
| 未指定     | Block      | 不绑定                |
| 未指定     | Filesystem | 绑定                  |
| Block      | 未指定     | 不绑定                |
| Block      | Block      | 绑定                  |
| Block      | Filesystem | 不绑定                |
| Filesystem | Filesystem | 绑定                  |
| Filesystem | Block      | 不绑定                |
| Filesystem | 未指定     | 绑定                  |

{% blockquote_note() %}
Alpha 发现版本中仅支持静态制备的卷。管理员需要在处理原始块设备时小心处理这些值。
{% end %}

### 对卷快照及卷快照中恢复卷的支持

**特性状态**：`v1.20 [stable]`

卷快照 Volume Snapshot 仅支持树外 CSI 卷插件。有关细节可参阅[卷快照](@/reads/2022-9-15-k8s-notes-vi.md#VolumeSnapshots)文档。

#### 基于卷快照创建 PVC

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: restore-pvc
spec:
  storageClassName: csi-hostpath-sc
  dataSource:
    name: new-snapshot-test
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
```

### 卷克隆

WIP

### 卷填充器与数据源

WIP

### 数据源引用

WIP

### 使用卷填充器

WIP

### 编写可移植的配置

WIP

## 投射卷 Projected Volumes

WIP

## 临时卷 Ephemeral Volumes

WIP

## 存储类 Storage Classes {#StorageClasses}

### 介绍 {#StorageClasses-Introduction}

StorageClass 为管理员提供了描述存储“类”的方法。不同的类型可能会映射到不同的服务质量等级或备份策略，或是由集群管理员定制的任意策略。k8s 本身并不清除各种类代表的什么。这个类的概念在其他存储系统中有时被称为“配置文件”。

### StorageClass 资源

每个 StorageClass 都包含 `provisioner`，`parameters` 和 `reclaimPolicy` 字段，这些字段会在 StorageClass 需要动态分配 PV 时会使用到。

StorageClass 对象的命名很重要，用户使用这个命名来请求生成一个特定的类。当创建 StorageClass 对象时，管理员设置 StorageClass 对象的命名和其他参数，一旦创建了对象就不能再对其更新。

管理员可以为没有申请绑定到特定 StorageClass 的 PVC 指定一个默认的存储类。

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp2
reclaimPolicy: Retain
allowVolumeExpansion: true
mountOptions:
  - debug
volumeBindingMode: Immediate
```

WIP

### 参数

Storage Classes 的参数描述了存储类的卷。取决于制备器，可以接受不同的参数。 例如，参数 type 的值 io1 和参数 iopsPerGB 特定于 EBS PV。 当参数被省略时，会使用默认值。

一个 StorageClass 最多可以定义 512 个参数。这些参数对象的总长度不能 超过 256 KiB, 包括参数的键和值。

#### 本地

**特性状态**：`v1.14 [stable]`

```yaml
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: local-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
```

本地卷还不支持动态制备，然而还是需要创建 StorageClass 以延迟卷绑定， 直到完成 Pod 的调度。这是由 `WaitForFirstConsumer` 卷绑定模式指定的。

延迟卷绑定使得调度器在为 PersistentVolumeClaim 选择一个合适的 PersistentVolume 时能考虑到所有 Pod 的调度限制。

## 动态卷制备 Dynamic Volume Provisioning {#DynamicVolumeProvisioning}

动态卷制备允许按需创建存储卷。如果没有动态制备，集群管理员必须手动的联系他们的云或存储提供商来创建新的存储卷，然后在 k8s 集群创建 PV 对象来表示这些卷。动态制备功能消除了集群管理员预先配置存储的需要。相反，它在用户请求时自动制备存储。

### 背景 {#DynamicVolumeProvisioning-Background}

动态卷制备的实现基于 `storage.k8s.io` API 组中的 `StorageClass` API 对象。集群管理员可以根据需要定义多个 `StorageClass` 对象，每个对象指定一个**卷插件 provisioner**，卷插件想卷制备商提供在创建卷时需要的数据卷信息及相关参数。

集群管理员可以在集群中定义和公开多种存储（来自相同或不同的存储系统），每种都具有自定义参数集。该设计也确保终端用户不必担心存储制备的复杂性和细微差别，但仍然能够从多个存储选项中进行选择。

### 启用动态卷制备

要启用动态制备功能，集群管理员需要为用户预先创建一个或多个 `StorageClass` 对象。`StorageClass` 对象定义当动态制备被调用时，哪一个驱动将被使用和哪些参数将被传递给驱动。StorageClass 对象的名字必须是一个合法的 DNS 子域名。以下清单创建了一个 `StorageClass` 存储类 “slow”，它提供类似标准磁盘的永久磁盘。

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: slow
provisioner: kubernetes.io/gce-pd
parameters:
  type: pd-standard
```

以下清单创建了一个 "fast" 存储类，它提供类似 SSD 的永久磁盘。

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast
provisioner: kubernetes.io/gce-pd
parameters:
  type: pd-ssd
```

### 使用动态卷制备

用户通过在 `PersistentVolumeClaim` 中包含存储类来请求动态制备的存储。在 k8s v1.9 之前，这通过 `volume.beta.kubernetes.io/storage-class` 注解实现。然而，这个注解自 v1.6 起就不被推荐使用了。用户现在能够而且应该使用 `PersistentVolumeClaim` 对象的 `storageClassName` 字段。这个字段的值必须能够匹配到集群管理员配置的 `StorageClass` 名称。

例如，要选择 “fast” 存储类，用户创建如下的 PersistentVolumeClaim：

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: claim1
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: fast
  resources:
    requests:
      storage: 30Gi
```

该声明会自动制备一块类似 SSD 的永久磁盘。 在删除该声明后，这个卷也会被销毁。

### 设置默认值的行为

可以在集群上启用动态卷制备，以便在未指定存储类的情况下动态设置所有声明。 集群管理员可以通过以下方式启用此行为：

- 标记一个 `StorageClass` 为**默认**；
- 确保 DefaultStorageClass 准入控制器在 API 服务端被启用。

管理员可以通过向其添加 `storageclass.kubernetes.io/is-default-class` annotation 来将特定的 `StorageClass` 标记为默认。 当集群中存在默认的 `StorageClass` 并且用户创建了一个未指定 `storageClassName` 的 `PersistentVolumeClaim` 时，`DefaultStorageClass` 准入控制器会自动向其中添加指向默认存储类的 `storageClassName` 字段。

请注意，集群上最多只能有一个 默认 存储类，否则无法创建没有明确指定 `storageClassName` 的 `PersistentVolumeClaim`。

### 拓扑感知

在多可用区集群中，Pod 可以被分散到某个区域的多个可用区。 单可用区存储后端应该被制备到 Pod 被调度到的可用区。 这可以通过设置卷绑定模式来实现。

## 卷快照 Volume Snapshots {#VolumeSnapshots}

WIP

## 卷快照类 Volume Snapshot Classes {#VolumeSnapshotsClasses}

WIP

## CSI 卷克隆 CSI Volume Cloning

WIP

## 存储容量 Storage Capacity

WIP

## 节点特定卷限制 Node-specific Volume Limits

WIP

## 卷健康监测 Volume Health Monitoring

WIP
