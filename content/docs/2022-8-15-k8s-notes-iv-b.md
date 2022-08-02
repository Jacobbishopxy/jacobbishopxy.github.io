+++
title="K8s 笔记 (IV) 下"
description="工作负载（工作负载资源）"
date=2022-08-15

[taxonomies]
categories = ["Doc"]
tags = ["k8s"]

[extra]
toc = true
+++

## Deployments

一个*Deployment*为 Pods 与 ReplicaSets 提供了声明式的更新。

在一个 Deployment 中用户描述一个*期望的状态*，接着 Deployment 控制器通过速度控制改变现有状态至期望状态。用户可以定义 Deployments 来创建新的 ReplicaSets，或者移除现有的 Deployments 并通过新的 Deployments 继承它们的资源。

> **注意：**
> 不要管理由 Deployment 所属的 ReplicaSets。

### 使用案例

以下是 Deployments 的典型使用案例：

- [创建一个 Deployment 以将 ReplicaSet 上线](@/docs/2022-8-15-k8s-notes-iv-b.md#CreatingADeployment)。ReplicaSet 在后台创建 Pods。检查上线状态确认其成功与否。

- [通过更新 Deployment 的 Pod 模版声明一个 Pods 的新状态](@/docs/2022-8-15-k8s-notes-iv-b.md#UpdatingADeployment)。一个新的 ReplicaSet 被创建，并且 Deployment 控速从旧的 ReplicaSet 移动 Pods 至新的。每个新的 ReplicaSet 都会更新 Deployment 的修订版本。

- [回滚到较早之前的 Deployment 版本](@/docs/2022-8-15-k8s-notes-iv-b.md#RollingBackADeployment)，如果当前状态的 Deployment 并不稳定。每次回滚都会更新 Deployment 的修订版本。

- [扩大 Deployment 规模用以承担更多负载](@/docs/2022-8-15-k8s-notes-iv-b.md#ScalingADeployment)。

- [暂停 Deployment](@/docs/2022-8-15-k8s-notes-iv-b.md#PausingAndResumingADeployment) 用以修复若干 Pod 模板，并恢复开始一个新的上线过程。

- [使用 Deployment 状态](@/docs/2022-8-15-k8s-notes-iv-b.md#DeploymentStatus)判断上线过程是否出现停滞。

- [清理较旧的不再需要的 ReplicaSet](@/docs/2022-8-15-k8s-notes-iv-b.md#CleanUpPolicy)。

#### 创建 Deployment {#CreatingADeployment}

以下是一个 Deployment 的例子。它创建了一个 ReplicaSet 负责启动三个 `nginx` Pods：

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
        - name: nginx
          image: nginx:1.14.2
          ports:
            - containerPort: 80
```

这个例子中：

- 名为 `nginx-deployment` 的 Deployment 被创建了，由字段 `.metadata.name` 字段表明。

- Deployment 创建了三个 Pods 副本，由字段 `.spec.replicas` 字段表明。

- `.spec.selector` 字段定义 Deployment 如何寻找 Pods 来管理。在这里，选择在 Pod 模版中定义的标签（`app: nginx`）。不过更复杂的选择规则也是可能得，只要 Pod 模板本身满足所给的规则即可。

  > **说明：** > `spec.selector.matchLabels` 字段是一个键值对映射。在 `matchLabels` 映射中的每个 `{key, value}` 映射等效于 `matchExpressions` 中的一个元素，即其 `key` 字段是 ”key“，`operator` 为 "In"，`values` 数组仅包含 ”value“。在 `matchLabels` 和 `matchExpressions` 中给出的所有条件都必须满足才能匹配。

- `template` 字段包含以下子字段：

  - Pod 被标记为 `app: nginx` 使用 `.metadata.labels` 字段。
  - Pod 模版规约，或者 `.template.spec` 字段，说明 Pods 运行在一个容器, `nginx`，运行 `nginx` Docker Hub 的 1.14.2 版本的镜像。
  - 创建一个容器并命名为 `nginx` 使用 `.spec.template.spec.containers[0].name` 字段。

在开始前，请确保 k8s 集群启动并正常运行中。根据下面步骤来创建上述的 Deployment：

1. 通过执行下面命令创建 Deployment：

   ```sh
   kubectl apply -f https://k8s.io/examples/controllers/nginx-deployment.yaml
   ```

1. 运行 `kubectl get deployments` 检查 Deployment 是否被创建。如果 Deployment 仍然在被创建，那么会有以下输出：

   ```txt
   NAME               READY   UP-TO-DATE   AVAILABLE   AGE
   nginx-deployment   0/3     0            0           1s
   ```

   当用户检查集群中的 Deployments 会显示下列字段：

   - `NAME` 例出集群中 Deployment 的名称。
   - `READY` 展示应用程序有多少个副本可用。它遵照 ready/desired 模式。
   - `UP-TO-DATE` 展示已经被更新到期望状态的副本数量。
   - `AVAILABLE` 展示应用可供用户使用的副本数。
   - `AGE` 显示应用程序运行的时间。

1. 查看 Deployment 的上线状态，运行 `kubectl rollout status deployment/nginx-deployment`。

   输出类似于：

   ```txt
   Waiting for rollout to finish: 2 out of 3 new replicas have been updated...
   deployment "nginx-deployment" successfully rolled out
   ```

1. 几秒过后再次运行 `kubectl get deployments`。输出类似于：

   ```txt
   NAME               READY   UP-TO-DATE   AVAILABLE   AGE
   nginx-deployment   3/3     3            3           18s
   ```

   注意 Deployment 已经创建了三个副本，并且所有副本都已经 up-to-date （它们包含了最新的 Pod 模板）并且可用了。

1. 查看由 Deployment 创建的 ReplicaSet（`rs`），运行 `kubectl get rs`。输出类似于：

   ```txt
   NAME                          DESIRED   CURRENT   READY   AGE
   nginx-deployment-75675f5897   3         3         3       18s
   ```

   ReplicaSet 显示下列字段：

   - `NAME` 列出 ReplicaSet 的名称。
   - `DESIRED` 展示应用所期望数量的*副本*。
   - `CURRENT` 展示正在运行的副本数量。
   - `READY` 展示应用可供用户使用的副本数。
   - `AGE` 展示应用已经运行的时间。

1. 查看每个 Pod 所自动创建的标签，运行 `kubectl get pods --show-labels`。输出类似于：

   ```txt
   NAME                                READY     STATUS    RESTARTS   AGE       LABELS
   nginx-deployment-75675f5897-7ci7o   1/1       Running   0          18s       app=nginx,pod-template-hash=3123191453
   nginx-deployment-75675f5897-kzszj   1/1       Running   0          18s       app=nginx,pod-template-hash=3123191453
   nginx-deployment-75675f5897-qqcnn   1/1       Running   0
   ```

   创建好的 ReplicaSet 确保拥有三个 `nginx` Pods。

### 更新 Deployment {#UpdatingADeployment}

> **注意：**
> Deployment 的上线仅且仅当 Deployment 的 Pod 模板（即 `.spec.template`）被更新时才会被触发，例如标签或模板的镜像被更新。其余的更新，例如扩展 Deployment 不会触发上线过程。

以下步骤更新 Deployment：

1. 更新 nginx Pods 使用 `nginx:1.16.1` 镜像而不是 `nginx:1.14.2` 镜像。

   ```sh
   kubectl set image deployment.v1.apps/nginx-deployment nginx=nginx:1.16.1
   ```

   或者：

   ```sh
   kubectl set image deployment/nginx-deployment nginx=nginx:1.16.1
   ```

   将会输出类似于：

   ```txt
   deployment.apps/nginx-deployment image updated
   ```

   另一种方式是通过 `edit` Deployment 修改 `.spec.template.spec.containers[0].image` 使 `nginx:1.14.2` 变为 `nginx:1.16.1`：

   ```sh
   kubectl edit deployment/nginx-deployment
   ```

   输出类似于：

   ```txt
   deployment.apps/nginx-deployment edited
   ```

1. 检查上线状态，运行：

   ```sh
   kubectl rollout status deployment/nginx-deployment
   ```

   输出类似于：

   ```txt
   Waiting for rollout to finish: 2 out of 3 new replicas have been updated...
   ```

   或者：

   ```txt
   deployment "nginx-deployment" successfully rolled out
   ```

   获取更多更新后的 Deployment 细节：

   - 当上线成功，用户可以通过 `kubectl get deployments` 检查 Deployment。输出类似于：

     ```txt
     NAME               READY   UP-TO-DATE   AVAILABLE   AGE
     nginx-deployment   3/3     3            3           36s
     ```

   - 运行 `kubectl get rs` 查看 Deployment 通过创建新的 ReplicaSet 并将其扩容到 3 个副本并将旧 ReplicaSet 缩容到 0 个副本完成了 Pod 的更新操作，输出类似于：

     ```txt
     NAME                          DESIRED   CURRENT   READY   AGE
     nginx-deployment-1564180365   3         3         3       6s
     nginx-deployment-2035384211   0         0         0       36s
     ```

   - 运行 `kubectl get pods` 现在应该只展示新 Pods，输出类似于：

     ```txt
     NAME                                READY     STATUS    RESTARTS   AGE
     nginx-deployment-1564180365-khku8   1/1       Running   0          14s
     nginx-deployment-1564180365-nacti   1/1       Running   0          14s
     nginx-deployment-1564180365-z9gth   1/1       Running   0
     ```

     下一次更新这些 Pods 时，用户只需要再次更新 Deployment 的 Pod 模板。

     Deployment 确保在 Pods 更新时只有一定数量的 Pods 关闭。默认情况下，它确保至少 75% 的预期数量的 Pods 处于运行状态（25% 最大不可用）。

   - 运行 `kubectl describe deployments` 获取 Deployment 的详细信息，输出类似于：

     ```txt
     Name:                   nginx-deployment
     Namespace:              default
     CreationTimestamp:      Thu, 30 Nov 2017 10:56:25 +0000
     Labels:                 app=nginx
     Annotations:            deployment.kubernetes.io/revision=2
     Selector:               app=nginx
     Replicas:               3 desired | 3 updated | 3 total | 3 available | 0 unavailable
     StrategyType:           RollingUpdate
     MinReadySeconds:        0
     RollingUpdateStrategy:  25% max unavailable, 25% max surge
     Pod Template:
       Labels:  app=nginx
       Containers:
         nginx:
           Image:        nginx:1.16.1
           Port:         80/TCP
           Environment:  <none>
           Mounts:       <none>
         Volumes:        <none>
       Conditions:
         Type           Status  Reason
         ----           ------  ------
         Available      True    MinimumReplicasAvailable
         Progressing    True    NewReplicaSetAvailable
       OldReplicaSets:  <none>
       NewReplicaSet:   nginx-deployment-1564180365 (3/3 replicas created)
       Events:
         Type    Reason             Age   From                   Message
         ----    ------             ----  ----                   -------
         Normal  ScalingReplicaSet  2m    deployment-controller  Scaled up replica set nginx-deployment-2035384211 to 3
         Normal  ScalingReplicaSet  24s   deployment-controller  Scaled up replica set nginx-deployment-1564180365 to 1
         Normal  ScalingReplicaSet  22s   deployment-controller  Scaled down replica set nginx-deployment-2035384211 to 2
         Normal  ScalingReplicaSet  22s   deployment-controller  Scaled up replica set nginx-deployment-1564180365 to 2
         Normal  ScalingReplicaSet  19s   deployment-controller  Scaled down replica set nginx-deployment-2035384211 to 1
         Normal  ScalingReplicaSet  19s   deployment-controller  Scaled up replica set nginx-deployment-1564180365 to 3
         Normal  ScalingReplicaSet  14s   deployment-controller  Scaled down replica set nginx-deployment-2035384211 to 0
     ```

### 回滚 Deployment {#RollingBackADeployment}

有时可能需要回滚一个 Deployment；例如当 Deployment 不稳定时导致的循环崩溃。默认情况下，所有的 Deployment 的回滚历史都会保存在系统中使得可以任何时候回滚（可以修改修订版本的历史限制）。

> **注意：**
> 一个 Deployment 的修订版本会在 Deployment 回滚触发时创建。这意味着只有修改 Deployment Pod 模板（`.spec.template`）改变后，新的修订版本才会被创建。其它的更新，例如扩展 Deployment，不会创建 Deployment 修订版本，因此用户可以同时执行手动缩放或自动缩放。换言之，当回滚到较早的修订版本时，只有 Deployment 的 Pod 模板部分会被回滚。

- 假设在更新 Deployment 时有一个 typo，把镜像的名称写成了 `nginx:1.161` 而不是 `nginx:1.16.1`：

  ```sh
  kubectl set image deployment/nginx-deployment nginx=nginx:1.161
  ```

  输出类似于：

  ```sh
  deployment.apps/nginx-deployment image updated
  ```

- 这个上线进程会停滞。可以通过命令检查上线状态：

  ```sh
  kubectl rollout status deployment/nginx-deployment
  ```

  输出类似于：

  ```txt
  Waiting for rollout to finish: 1 out of 3 new replicas have been updated...
  ```

- Ctrl-C 结束状态查看。

- 可以看到旧副本（`nginx-deployment-1564180365` 和 `nginx-deployment-2035384211`）的数量是 2，新副本（`nginx-deployment-3066724191`）的数量是 1.

  ```sh
  kubectl get rs
  ```

  输出类似于：

  ```txt
  NAME                          DESIRED   CURRENT   READY   AGE
  nginx-deployment-1564180365   3         3         3       25s
  nginx-deployment-2035384211   0         0         0       36s
  nginx-deployment-3066724191   1         1         0       6s
  ```

- 检查被创建的 Pods，可以看到一个新 ReplicaSet 创建的 Pod 停滞在拉取镜像的环节。

  ```sh
  kubectl get pods
  ```

  输出类似于：

  ```txt
  NAME                                READY     STATUS             RESTARTS   AGE
  nginx-deployment-1564180365-70iae   1/1       Running            0          25s
  nginx-deployment-1564180365-jbqqo   1/1       Running            0          25s
  nginx-deployment-1564180365-hysrc   1/1       Running            0          25s
  nginx-deployment-3066724191-08mng   0/1       ImagePullBackOff   0          6s
  ```

  > **注意：**
  > Deployment 控制器会自动停止坏的上线过程，并停止扩展新的 ReplicaSet。这是依赖于用户可以指定的 rollingUpdate 参数（`maxUnavailable`）。k8s 默认设置该值为 25%。

- 通过 `kubectl describe deployment` 获取 Deployment 详细信息，输出类似于：

  ```txt
  Name:           nginx-deployment
  Namespace:      default
  CreationTimestamp:  Tue, 15 Mar 2016 14:48:04 -0700
  Labels:         app=nginx
  Selector:       app=nginx
  Replicas:       3 desired | 1 updated | 4 total | 3 available | 1 unavailable
  StrategyType:       RollingUpdate
  MinReadySeconds:    0
  RollingUpdateStrategy:  25% max unavailable, 25% max surge
  Pod Template:
    Labels:  app=nginx
    Containers:
    nginx:
      Image:        nginx:1.161
      Port:         80/TCP
      Host Port:    0/TCP
      Environment:  <none>
      Mounts:       <none>
    Volumes:        <none>
  Conditions:
    Type           Status  Reason
    ----           ------  ------
    Available      True    MinimumReplicasAvailable
    Progressing    True    ReplicaSetUpdated
  OldReplicaSets:     nginx-deployment-1564180365 (3/3 replicas created)
  NewReplicaSet:      nginx-deployment-3066724191 (1/1 replicas created)
  Events:
    FirstSeen LastSeen    Count   From                    SubObjectPath   Type        Reason              Message
    --------- --------    -----   ----                    -------------   --------    ------              -------
    1m        1m          1       {deployment-controller }                Normal      ScalingReplicaSet   Scaled up replica set nginx-deployment-2035384211 to 3
    22s       22s         1       {deployment-controller }                Normal      ScalingReplicaSet   Scaled up replica set nginx-deployment-1564180365 to 1
    22s       22s         1       {deployment-controller }                Normal      ScalingReplicaSet   Scaled down replica set nginx-deployment-2035384211 to 2
    22s       22s         1       {deployment-controller }                Normal      ScalingReplicaSet   Scaled up replica set nginx-deployment-1564180365 to 2
    21s       21s         1       {deployment-controller }                Normal      ScalingReplicaSet   Scaled down replica set nginx-deployment-2035384211 to 1
    21s       21s         1       {deployment-controller }                Normal      ScalingReplicaSet   Scaled up replica set nginx-deployment-1564180365 to 3
    13s       13s         1       {deployment-controller }                Normal      ScalingReplicaSet   Scaled down replica set nginx-deployment-2035384211 to 0
    13s       13s         1       {deployment-controller }                Normal      ScalingReplicaSet   Scaled up replica set nginx-deployment-3066724191 to 1
  ```

  修复此状态，用户需要回滚到上一个稳定的 Deployment 修订版本。

#### 检查 Deployment 上线历史

以下步骤检查回滚历史：

1. 首先检查改 Deployment 的修订版本：

   ```sh
   kubectl rollout history deployment/nginx-deployment
   ```

   输出类似于：

   ```txt
   deployments "nginx-deployment"
   REVISION    CHANGE-CAUSE
   1           kubectl apply --filename=https://k8s.io/examples/controllers/nginx-deployment.yaml
   2           kubectl set image deployment/nginx-deployment nginx=nginx:1.16.1
   3           kubectl set image deployment/nginx-deployment nginx=nginx:1.161
   ```

   `CHANGE-CAUSE` 的内容在修订版本被创建时，从 Deployment 的注解 `kubernetes.io/change-cause` 复制而来。用户可以通过下列方式设置 `CHANGE-CAUSE` 信息：

   - 使用 `kubectl annotate deployment/nginx-deployment kubernetes.io/change-cause="image updated to 1.16.1"` 为 Deployment 添加注解。
   - 手动编辑资源清单。

1. 查看每个修订历史的详细信息，运行：

   ```sh
   kubectl rollout history deployment/nginx-deployment --revision=2
   ```

   输出类似于：

   ```txt
   deployments "nginx-deployment" revision 2
     Labels:       app=nginx
             pod-template-hash=1159050644
     Annotations:  kubernetes.io/change-cause=kubectl set image deployment/nginx-deployment nginx=nginx:1.16.1
     Containers:
     nginx:
       Image:      nginx:1.16.1
       Port:       80/TCP
       QoS Tier:
           cpu:      BestEffort
           memory:   BestEffort
       Environment Variables:      <none>
     No volumes.
   ```

#### 回滚到之前的修订版本

以下步骤回滚当前版本的 Deployment 到前一个版本，即版本 2。

1. 撤销当前上线，并回滚至上个版本：

   ```sh
   kubectl rollout undo deployment/nginx-deployment
   ```

   输出类似于：

   ```txt
   deployment.apps/nginx-deployment rolled back
   ```

   现在 Deployment 回滚到了上一个文档版本。可以看到，`DeploymentRollback` 回滚至版本 2 的事件是由 Deployment 控制器所生成的。

1. 检查回滚是否成功，以及 Deployment 的运行是否达到预期，运行：

   ```sh
   kubectl get deployment nginx-deployment
   ```

   输出类似于：

   ```txt
   NAME               READY   UP-TO-DATE   AVAILABLE   AGE
   nginx-deployment   3/3     3            3           30m
   ```

1. 通过 `kubectl describe deployment nginx-deployment` 获取 Deployment 描述，输出类似于：

   ```txt
   Name:                   nginx-deployment
   Namespace:              default
   CreationTimestamp:      Sun, 02 Sep 2018 18:17:55 -0500
   Labels:                 app=nginx
   Annotations:            deployment.kubernetes.io/revision=4
                           kubernetes.io/change-cause=kubectl set image deployment/nginx-deployment nginx=nginx:1.16.1
   Selector:               app=nginx
   Replicas:               3 desired | 3 updated | 3 total | 3 available | 0 unavailable
   StrategyType:           RollingUpdate
   MinReadySeconds:        0
   RollingUpdateStrategy:  25% max unavailable, 25% max surge
   Pod Template:
     Labels:  app=nginx
     Containers:
     nginx:
       Image:        nginx:1.16.1
       Port:         80/TCP
       Host Port:    0/TCP
       Environment:  <none>
       Mounts:       <none>
     Volumes:        <none>
   Conditions:
     Type           Status  Reason
     ----           ------  ------
     Available      True    MinimumReplicasAvailable
     Progressing    True    NewReplicaSetAvailable
   OldReplicaSets:  <none>
   NewReplicaSet:   nginx-deployment-c4747d96c (3/3 replicas created)
   Events:
     Type    Reason              Age   From                   Message
     ----    ------              ----  ----                   -------
     Normal  ScalingReplicaSet   12m   deployment-controller  Scaled up replica set nginx-deployment-75675f5897 to 3
     Normal  ScalingReplicaSet   11m   deployment-controller  Scaled up replica set nginx-deployment-c4747d96c to 1
     Normal  ScalingReplicaSet   11m   deployment-controller  Scaled down replica set nginx-deployment-75675f5897 to 2
     Normal  ScalingReplicaSet   11m   deployment-controller  Scaled up replica set nginx-deployment-c4747d96c to 2
     Normal  ScalingReplicaSet   11m   deployment-controller  Scaled down replica set nginx-deployment-75675f5897 to 1
     Normal  ScalingReplicaSet   11m   deployment-controller  Scaled up replica set nginx-deployment-c4747d96c to 3
     Normal  ScalingReplicaSet   11m   deployment-controller  Scaled down replica set nginx-deployment-75675f5897 to 0
     Normal  ScalingReplicaSet   11m   deployment-controller  Scaled up replica set nginx-deployment-595696685f to 1
     Normal  DeploymentRollback  15s   deployment-controller  Rolled back deployment "nginx-deployment" to revision 2
     Normal  ScalingReplicaSet   15s   deployment-controller  Scaled down replica set nginx-deployment-595696685f to 0
   ```

### 缩放 Deployment {#ScalingADeployment}

可以通过以下命令扩展一个 Deployment：

```sh
kubectl scale deployment/nginx-deployment --replicas=10
```

输出类似于：

```txt
deployment.apps/nginx-deployment scaled
```

假设用户的集群开启了水平 Pod 自动扩展，那么可以为 Deployment 设置自动缩放器 autoscaler，并根据现有 Pods 的 CPU 利用率，选择期望的最小和最大的 Pods 数量。

```sh
kubectl autoscale deployment/nginx-deployment --min=10 --max=15 --cpu-percent=80
```

输出类似于：

```txt
deployment.apps/nginx-deployment scaled
```

#### 按比例缩放

滚动更新（RollingUpdate） Deployment 支持同一时间内运行若干版本的应用程序。当用户或者自动缩放器，在上线（无论是正在进行的还是暂停着的）的途中，缩放了一个滚动更新 Deployment，那么为了减轻风险， Deployment 控制器会平衡额外的副本在现有的运行状态的 ReplicaSets（带有 Pods 的 ReplicaSets）。

例如，用户正在运行一个拥有 10 个副本的 Deployment，maxSurge=3 以及 maxUnavailable=2。

- 确保这 10 个副本正在运行：

  ```sh
  kubectl get deploy
  ```

  输出类似于：

  ```txt
  NAME                 DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
  nginx-deployment     10        10        10           10          50s
  ```

- 更新 Deployment 使用新的镜像，刚好该镜像无法从集群内部解析。

  ```sh
  kubectl set image deployment/nginx-deployment nginx=nginx:sometag
  ```

  输出类似于：

  ```txt
  deployment.apps/nginx-deployment image updated
  ```

- 镜像更新开始了一个带有 ReplicaSet `nginx-deployment-1989198191` 的新上线，但是因为上面设置的 `maxUnavailable` 参数阻塞了，通过 `kubectl get rs` 检查上线状态，输出类似于：

  ```txt
  NAME                          DESIRED   CURRENT   READY     AGE
  nginx-deployment-1989198191   5         5         0         9s
  nginx-deployment-618515232    8         8         8         1m
  ```

- 接着出现了新的 Deployment 缩放请求。自动缩放器将 Deployment 副本增加到 15。Deployment 控制器需要决定在哪里添加 5 个新的副本。如果使用的是按比例缩放，那么这 5 个副本将会被添加至新的 ReplicaSet。通过按比例缩放，可以将额外的副本分布到所有的 ReplicaSet。较大比例的副本会被添加到拥有最多副本的 ReplicaSet，而较低比例的副本会进入到副本较少的 ReplicaSet。所有剩下的副本都会添加到副本最多的 ReplicaSet。具有零副本的 ReplicaSet 不会被扩容。

在上面的示例中，3 个副本被添加到旧 ReplicaSet 中，2 个副本被添加到新 ReplicaSet 中。假设新的副本健康，上线过程最终应该将所有副本迁移到新的 ReplicaSet 中。通过 `kubectl get deploy` 可以确认，并输出类似于：

```txt
NAME                 DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
nginx-deployment     15        18        7            8           7m
```

上线状态确认了副本是如何被添加到每个 ReplicaSet 的。通过 `kubectl get rs` 输出类似于：

```txt
NAME                          DESIRED   CURRENT   READY     AGE
nginx-deployment-1989198191   7         7         0         7m
nginx-deployment-618515232    11        11        11        7m
```

### 暂停和恢复上线 {#PausingAndResumingADeployment}

更新一个 Deployment 时，或者是计划更新时，用户可以在触发一个或多个更新前暂停上线。当准备好应用这些更新时，用户可以为 Deployment 恢复上线。这个方法允许用户在暂停和恢复期间，应用若干修复而不触发没有必要的上线过程。

- 例如，一个已经创建了的 Deployment，通过 `kubectl get deploy` 获取其明细，输出类似于：

  ```txt
  NAME      DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
  nginx     3         3         3            3           1m
  ```

  通过 `kubectl get rs`，输出类似于：

  ```txt
  NAME               DESIRED   CURRENT   READY     AGE
  nginx-2142116321   3         3         3         1m
  ```

- 通过 `kubectl rollout pause deployment/nginx-deployment` 命令暂停上线，输出类似于：

  ```txt
  deployment.apps/nginx-deployment paused
  ```

- 接着 `kubectl set image deployment/nginx-deployment nginx=nginx:1.16.1` 更新 Deployment 的镜像，输出类似于：

  ```txt
  deployment.apps/nginx-deployment image updated
  ```

- 注意没有新的上线过程开始，通过 `kubectl rollout history deployment/nginx-deployment` 检查，输出类似于：

  ```txt
  deployments "nginx"
  REVISION  CHANGE-CAUSE
  1   <none>
  ```

- 获取上线状态确认现存的 ReplicaSet 没有变化，通过 `kubectl get rs` 检查，输出类似于：

  ```txt
  NAME               DESIRED   CURRENT   READY     AGE
  nginx-2142116321   3         3         3         2m
  ```

- 用户可以根据需要执行很多更新操作，例如通过 `kubectl set resources deployment/nginx-deployment -c=nginx --limits=cpu=200m,memory=512Mi` 更新所需的资源，输出类似于：

  ```txt
  deployment.apps/nginx-deployment resource requirements updated
  ```

  暂停 Deployment 上线之前的初始状态将继续发挥作用，但新的更新在 Deployment 上线被暂停期间不会产生任何效果。

- 最终，通过 `kubectl rollout resume deployment/nginx-deployment`，恢复 Deployment 上线，并观察新的 ReplicaSet 创建的过程，其中包含了所有应用的所有更新，输出类似于：

  ```txt
  deployment.apps/nginx-deployment resumed
  ```

- 通过 `kubectl get rs -w` 观察上线状态，直到其完成，输出类似于：

  ```txt
  NAME               DESIRED   CURRENT   READY     AGE
  nginx-2142116321   2         2         2         2m
  nginx-3926361531   2         2         0         6s
  nginx-3926361531   2         2         1         18s
  nginx-2142116321   1         2         2         2m
  nginx-2142116321   1         2         2         2m
  nginx-3926361531   3         2         1         18s
  nginx-3926361531   3         2         1         18s
  nginx-2142116321   1         1         1         2m
  nginx-3926361531   3         3         1         18s
  nginx-3926361531   3         3         2         19s
  nginx-2142116321   0         1         1         2m
  nginx-2142116321   0         1         1         2m
  nginx-2142116321   0         0         0         2m
  nginx-3926361531   3         3         3         20s
  ```

- 通过 `kubectl get rs` 获取最新的上线状态，输出类似于：

  ```txt
  NAME               DESIRED   CURRENT   READY     AGE
  nginx-2142116321   0         0         0         2m
  nginx-3926361531   3         3         3         28s
  ```

> **注意：**
> 不可以回滚处于暂停状态的 Deployment 除非先恢复它。

### Deployment 状态 {#DeploymentStatus}

Deployment 在其存续期间，会进入不同的状态。可以是在上线新的 ReplicaSet 时的进行中（progressing），可以是完成（complete），或者是失败（failed）。

#### 进行中的 Deployment

当以下任务被执行时，k8s 会标记 Deployment 为*进行中 progressing*：

- Deployment 创建一个新的 ReplicaSet。
- Deployment 扩容新的 ReplicaSet。
- Deployment 缩容旧的 ReplicaSet(s)。
- 新的 Pods 准备就绪或是可用了（就绪至少持续了 MinReadySeconds 秒）。

当上线状态变为“进行中”，Deployment 控制器添加包含下列属性的条件至 Deployment 的 `.status.conditions`：

- `type: Progressing`
- `status: "True"`
- `reason: NewReplicaSetCreated` | `reason: FoundNewReplicaSet` | `reason: ReplicaSetUpdated`

用户可以使用 `kubectl rollout status` 监控 Deployment 的进度。

#### 完成的 Deployment

当以下特征出现时，k8s 会标记 Deployment 为*完成 complete*：

- 所有与 Deployment 相关的副本都被更新到了最新的版本，意味着任何用户请求的更新都完成了。
- 所有与 Deployment 相关的副本都可用了。
- Deployment 的旧副本不再运行。

当上新状态变为“完成”，Deployment 控制器添加包含下列属性的条件至 Deployment 的 `.status.conditions`：

- `type: Progressing`
- `status: "True"`
- `reason: NewReplicaSetAvailable`

`Progressing` 状况会持续为 `"True"`，直到新的上线被触发。即使副本的可用状态发生变化（进而影响 `Available` 状况），`Progressing` 状况的值也不会变化。

可以通过 `kubectl rollout status` 检查一个 Deployment 是否完成。如果上线成功完成，`kubectl rollout status` 返回退出代码 0。

```sh
kubectl rollout status deployment/nginx-deployment
```

输出类似于：

```txt
Waiting for rollout to finish: 2 of 3 updated replicas are available...
deployment "nginx-deployment" successfully rolled out
```

#### 失败的 Deployment

Deployment 在部署最新的 ReplicaSet 时，会遇到阻塞并一直处于未完成的状态。这可能有以下几个因素造成：

- 配额（quota）不足
- 就绪探测（readiness probe）失败
- 镜像拉取错误
- 权限不足
- 限制范围（limit ranges）
- 应用程序运行时的配置错误

检测此状况的方法之一是在 Deployment 规约中指定截止时间参数：（`.spec.progressDeadlineSeconds`）。`.spec.progressDeadlineSeconds` 给出的是一个秒数值，Deployment 控制器在（通过 Deployment 状态）标识 Deployment 进展停滞之前，需要等待所给的时长。

以下 `kubectl` 命令设置规约中的 `progressDeadlineSeconds` 使得控制器在 10 分钟后报告 Deployment 没有进展：

```sh
kubectl patch deployment/nginx-deployment -p '{"spec":{"progressDeadlineSeconds":600}}'
```

输出类似于：

```txt
deployment.apps/nginx-deployment patched
```

一旦超过了截止时间，Deployment 控制器会添加包含下列属性的状况到 Deployment 的 `.status.conditions` 中：

- `type: Progressing`
- `status: "False"`
- `reason: ProgressDeadlineExceeded`

这个状况也可能会在较早的时候失败，因而其状态被设为 `"False"`，这是因为 `ReplicaSetCreateError`。一旦 Deployment 上线完成，就不再考虑截止时间。

#### 对失败 Deployment 的操作

所有用在已完成的 Deployment 的操作也适用于失败的 Deployment 上。用户可以对其阔缩容，回滚至前一个修订版本，或是需要对 Deployment 的 Pod 模板应用多项调整时将 Deployment 暂停。

### 清理策略 {#CleanUpPolicy}

可以在 Deployment 中设置 `.spec.revisionHistoryLimit` 字段来指定保留该 Deployment 的旧 ReplicaSet。其余的 ReplicaSet 将在后台被垃圾回收。默认情况下，该值为 10。

> **说明：**
> 显式将此字段设置为 0 将导致 Deployment 的所有历史记录被清空，因此 Deployment 将无法回滚。

### 金丝雀部署

如果要是用 Deployment 向用户子集或服务器子集上线版本，可以遵守资源管理所描述的金丝雀模式，为每个版本创建一个 Deployment。

### 编写 Deployment 规约

与其它 k8s 配置一样，Deployment 需要 `.apiVersion`，`.kind` 以及 `.metadata` 字段。

Deployment 对象的名称必须是合法的 DNS 子域名。Deployment 还需要 `.spec` 部分。

#### Pod 模板

WIP

#### 副本

WIP

#### 选择符

WIP

#### 策略

WIP

#### 进度期限秒数

WIP

#### 最短就绪时间

WIP

#### 修订历史限制

WIP

## ReplicaSet

WIP

## StatefulSets

WIP

## DaemonSet

WIP

## Jobs

WIP

## 已完成 Jobs 的自动清理

WIP

## CronJob

WIP

## ReplicationController

WIP
