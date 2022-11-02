+++
title="K8s 笔记 (IV) 下"
description="工作负载（负载资源）"
date=2022-08-15

[taxonomies]
categories = ["Doc"]
tags = ["k8s"]

[extra]
toc = true
+++

## Deployments

一个 Deployment 为 Pods 与 ReplicaSets 提供了声明式的更新。

在一个 Deployment 中用户描述一个*期望的状态*，接着 Deployment 控制器通过速度控制改变现有状态至期望状态。用户可以定义 Deployments 来创建新的 ReplicaSets，或者移除现有的 Deployments 并通过新的 Deployments 继承它们的资源。

{% blockquote_note() %}
不要管理由 Deployment 所属的 ReplicaSets。
{% end %}

### 使用案例

以下是 Deployments 的典型使用案例：

- [创建一个 Deployment 以将 ReplicaSet 上线](@/reads/2022-8-15-k8s-notes-iv-b.md#CreatingADeployment)。ReplicaSet 在后台创建 Pods。检查上线状态确认其成功与否。

- [通过更新 Deployment 的 Pod 模版声明一个 Pods 的新状态](@/reads/2022-8-15-k8s-notes-iv-b.md#UpdatingADeployment)。一个新的 ReplicaSet 被创建，并且 Deployment 控速从旧的 ReplicaSet 移动 Pods 至新的。每个新的 ReplicaSet 都会更新 Deployment 的修订版本。

- [回滚到较早之前的 Deployment 版本](@/reads/2022-8-15-k8s-notes-iv-b.md#RollingBackADeployment)，如果当前状态的 Deployment 并不稳定。每次回滚都会更新 Deployment 的修订版本。

- [扩大 Deployment 规模用以承担更多负载](@/reads/2022-8-15-k8s-notes-iv-b.md#ScalingADeployment)。

- [暂停 Deployment](@/reads/2022-8-15-k8s-notes-iv-b.md#PausingAndResumingADeployment) 用以修复若干 Pod 模板，并恢复开始一个新的上线过程。

- [使用 Deployment 状态](@/reads/2022-8-15-k8s-notes-iv-b.md#DeploymentStatus)判断上线过程是否出现停滞。

- [清理较旧的不再需要的 ReplicaSet](@/reads/2022-8-15-k8s-notes-iv-b.md#CleanUpPolicy)。

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

  {% blockquote_note() %}
  `spec.selector.matchLabels` 字段是一个键值对映射。在 `matchLabels` 映射中的每个 `{key, value}` 映射等效于 `matchExpressions` 中的一个元素，即其 `key` 字段是 ”key“，`operator` 为 "In"，`values` 数组仅包含 ”value“。在 `matchLabels` 和 `matchExpressions` 中给出的所有条件都必须满足才能匹配。
  {% end %}

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

{% blockquote_note() %}
Deployment 的上线仅且仅当 Deployment 的 Pod 模板（即 `.spec.template`）被更新时才会被触发，例如标签或模板的镜像被更新。其余的更新，例如扩展 Deployment 不会触发上线过程。
{% end %}

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

{% blockquote_note() %}
一个 Deployment 的修订版本会在 Deployment 回滚触发时创建。这意味着只有修改 Deployment Pod 模板（`.spec.template`）改变后，新的修订版本才会被创建。其它的更新，例如扩展 Deployment，不会创建 Deployment 修订版本，因此用户可以同时执行手动缩放或自动缩放。换言之，当回滚到较早的修订版本时，只有 Deployment 的 Pod 模板部分会被回滚。
{% end %}

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

  {% blockquote_note() %}
  Deployment 控制器会自动停止坏的上线过程，并停止扩展新的 ReplicaSet。这是依赖于用户可以指定的 rollingUpdate 参数（`maxUnavailable`）。k8s 默认设置该值为 25%。
  {% end %}

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

### 扩缩 Deployment {#ScalingADeployment}

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

{% blockquote_note() %}
不可以回滚处于暂停状态的 Deployment 除非先恢复它。
{% end %}

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

{% blockquote_note() %}
显式将此字段设置为 0 将导致 Deployment 的所有历史记录被清空，因此 Deployment 将无法回滚。
{% end %}

### 金丝雀部署

如果要是用 Deployment 向用户子集或服务器子集上线版本，可以遵守资源管理所描述的金丝雀模式，为每个版本创建一个 Deployment。

### 编写 Deployment 规约

与其它 k8s 配置一样，Deployment 需要 `.apiVersion`，`.kind` 以及 `.metadata` 字段。

Deployment 对象的名称必须是合法的 DNS 子域名。Deployment 还需要 `.spec` 部分。

#### Pod 模板 {#DeploymentsPodTemplate}

`.spec` 仅需要两个字段 `.spec.template` 与 `.spec.selector`。

`.spec.template` 是一个 Pod 模板。它拥有与 Pod 完全相同的规则，因为是嵌套的，所以不需要 `apiVersion` 或 `kind`。

除了 Pod 需要的字段，Deployment 的 Pod 模板必须指定合适的标签以及合适的重启策略。对于标签而言，确保不要与其它控制器重叠。

只有 `.spec.template.spec.restartPolicy` 等于 `Always` 是允许的，这也是没有指定情况下的默认值。

#### 副本

`.spec.replicas` 是一个可选字段，用于指定期望 Pods 的数量。其默认值为 1。

如果你对某个 Deployment 执行了手动扩缩操作（例如通过 `kubectl scale deployment deployment --replicas=X`），之后根据清单对 Deployment 执行了更新操作（例如通过运行 `kubectl apply -f deployment.yaml`），那么通过应用清单完成的更新会覆盖之前手动扩缩的变更。

如果一个 HorizontalPodAutoscaler（或者其他执行水平扩缩操作的类似 API）在管理 Deployment 的扩缩，则不要设置 `.spec.replicas`。

相反的，应该允许 k8s 控制面来自动管理 `.spec.replicas` 字段。

#### 选择符

`.spec.selector` 是一个必须字段，用于指定该 Deployment 目标 Pods 的标签选择符。

`.spec.selector` 必须匹配 `.spec.template.metadata.labels`，否则它会被 API 拒绝。

API 版本 `apps/v1`，`.spec.selector` 以及 `.metadata.labels` 不会默认设置为 `.spec.template.metadata.labels`，所以需要明确的进行设置。同时注意 `.spec.selector` 在 Deployment 创建 `apps/v1` 后是不可变的。

Deployment 可能会终结匹配到标签 selector 的 Pods，如果它们的模板不同于 `.spec.template` 或者该 Pods 总数超出 `.spec.replicas`。它也会创建带有 `.spec.template` 的新 Pods，如果 Pods 的总数小于期望值。

{% blockquote_note() %}
用户不该直接创建与此选择符匹配的 Pods，无论是直接通过另一个 Deployment，或者是另一个控制器例如 ReplicaSet 或者一个 ReplicationController。如果用户这么做了，第一个 Deployment 会认为它创建了这些 Pod。k8s 不会阻止该行为。
{% end %}

如果有多个控制器的选择符发生重叠，则控制器之间会因为冲突而无法正常工作。

#### 策略

`.spec.strategy` 用于指定更新旧 Pod 的策略。`.spec.strategy.type` 可以是“重新创建”或者是“滚动更新”，后者是默认值。

##### 重建 Deployment

当 `.spec.strategy.type==Recreate` 时，所有现存的 Pods 会在新的 Pods 创建之前被杀死。

{% blockquote_note() %}
这只会确保为了升级而创建新 Pod 之前其他 Pod 都已经终止。如果升级一个 Deployment，所有旧版本的 Pod 都会被立刻终止。控制器等待这些 Pod 被成功移除之后才会创建新版本的 Pod。如果手动删除一个 Pod，其生命周期是由 ReplicaSet 控制的，后者会立刻创建一个替换 Pod（即使旧的 Pod 仍然处于 Terminating 状态）。如果用户需要一种“最多 n 个”的 Pod 个数保证，则需要使用 StatefulSet。
{% end %}

##### 滚动更新 Deployment

当 `.spec.strategy.type==RollingUpdate` 时，Deployment 更新 Pods 会以滚动方式更新。用户可以指定 `maxUnavailable` 和 `maxSurge` 来控制滚动更新过程。

###### 最大不可用

`.spec.strategy.rollingUpdate.maxUnavailable` 是一个可选字段，用于指定在更新过程中，最大不可用 Pods 的数量。该值可以是绝对数值（例如 5）或者是期望 Pods 的百分比（例如 10%）。百分比值会转换成绝对数并去除小数部分。如果 `.spec.strategy.rollingUpdate.maxSurge` 为 0，则最大不可用不能为 0。最大不可用默认值为 25%。

###### 最大峰值

`.spec.strategy.rollingUpdate.maxSurge` 是一个可选字段，用于指定可以创建的超出期望 Pod 的数量。该值可以是绝对数值（例如 5）或者是期望 Pods 的百分比（例如 10%）。如果 `.spec.strategy.rollingUpdate.maxUnavailable` 为 0，则最大峰值不可为 0。百分比值会通过向上取整转换为绝对数值。最大峰值默认值为 25%。

#### 进度期限秒数

`.spec.progressDeadlineSeconds` 是一个可选字段，用于指定期望 Deployment 在进展失败之前，等待其取得进展的秒数。该报告会在资源状态中体现为 `type: Progressing`，`status: False`，`reason: ProgressDeadlineExceeded`。Deployment 控制器将持续重试 Deployment。之后只要实现了自动回滚，Deployment 控制器将在探测到这样的条件时立刻回滚 Deployment。

如果指定，该值需要大于 `.spec.minReadySeconds` 的值。

#### 最短就绪时间

`.spec.minReadySeconds` 是一个可选字段，用于指定新创建的 Pod 在没有任何容器崩溃的情况下最短的就绪时间，只有超出这个时间 Pod 才会被视为可用。该值默认值为 0（即 Pod 在准备就绪后立刻被视为可用）。了解何时 Pod 被视为就绪，请参考容器探针。

#### 修订历史限制

Deployment 的修订历史记录存储在它所控制的 ReplicaSet 中。

`.spec.revisionHistoryLimit` 是一个可选字段，用于指定回滚时所需要保留的旧 ReplicaSet 数量。这些旧 ReplicaSet 会消耗 etcd 中的资源，并占用 `kubectl get rs` 的输出。每个 Deployment 修订版本的配置都存储在其 ReplicaSets 中；一旦删除了旧 ReplicaSet，将失去回滚到 Deployment 的对应修订版本的能力。默认系统保留 10 个旧 ReplicaSet，但是其理想值取决于新 Deployment 的频率和稳定性。

更具体的说，此字段设置为 0 意味着将清理所有具有 0 个副本的旧 ReplicaSet。这种情况下，无法撤销新的 Deployment 上线，因为它的修订历史被清除了。

#### 暂停的（Paused）

`.spec.paused` 用于暂停和恢复 Deployment 的可选布尔字段。暂停的 Deployment 和未暂停的 Deployment 的唯一区别在于 Deployment 处于暂停状态时，PodTemplateSpec 的任何修改都不会触发新的上线。Deployment 在创建时是默认不会处于暂停状态。

## ReplicaSet

ReplicaSet 的目的在于维护组在任何时候都处于运行状态的 Pods 副本的稳定集合。因此它通常用于保障给定数量的且完全相同的 Pods 可用性。

### ReplicaSet 工作原理

ReplicaSet 定义了一些字段，包含用于指定如何获取 Pod 的选择符，需要维护的副本数量，用于指定应该创建多少新 Pods 来达成副本条件的 pod 模板等。ReplicaSet 根据需要创建和删除 Pod 使得副本个数达到期望值，进而体现其存在价值。当 ReplicaSet 需要创建新的 Pod 时，会使用所提供的 Pod 模板。

ReplicaSet 通过 Pods 的 metadata.ownerReferences 字段来连接其 Pods，该字段指定了当前对象被何种资源所拥有。ReplicaSet 所获得的所有 Pods 都在其 ownerReferences 字段中包含了属主 ReplicaSet 的标识信息。通过这个连接 ReplicaSet 才能正确的知道其维护与计划的 Pods 的状态。

ReplicaSet 通过使用其选择符来识别要获取的新 Pods。如果一个 Pod 没有 OwnerReference 或者 OwnerReference 不是一个控制器并且匹配到一个 ReplicaSet 选择符，则该 Pod 立刻被此 ReplicaSet 获得。

### 何时使用 ReplicaSet

ReplicaSet 确保规定数量的 pod 副本可以在任何时候都处于运行状态。然而，Deployment 是更高阶的概念，其用作于管理 ReplicaSets 并为 Pods 提供声明式的更新，以及其它有用的功能。因此，我们建议使用 Deployments 而不是直接使用 ReplicaSets，除非用户需要自定义更新业务流程或根本不需要更新。

这就意味着，用户可能永远不需要操作 ReplicaSet 对象：而是使用 Deployment，并在 spec 部分定义应用。

### 示例 {#ReplicaSetExample}

WIP

### 非模板 Pod 获取

WIP

### 编写 ReplicaSet 清单

WIP

#### Pod 模板编写

WIP

#### Pod 选择符 {#ReplicaSetPodSelector}

WIP

#### Replicas

WIP

### 使用 ReplicaSet

WIP

#### 删除 ReplicaSet 与其 Pods

WIP

#### 仅删除 ReplicaSet

WIP

#### 将 Pod 从 ReplicaSet 中隔离

WIP

#### 扩缩 ReplicaSet

WIP

#### Pod 删除开销

WIP

#### ReplicaSet 作为水平的 Pod 自动扩缩器目标

WIP

### ReplicaSet 替代方案

WIP

#### Deployment（推荐）

WIP

#### 裸 Pod {#AlternativesToReplicaSetBarePods}

WIP

#### Job {#AlternativesToReplicaSetJob}

WIP

#### DaemonSet {#AlternativesToReplicaSetDaemonSet}

WIP

#### ReplicationController {#AlternativesToReplicaSetReplicationController}

WIP

## StatefulSets

StatefulSet 用于管理带有状态的应用程序的工作负载 API 对象。

管理 Pods 集合的部署和扩缩，并且为这些 Pods 提供*排序与唯一性的保障*。

与 Deployment 类似，StatefulSet 根据相同容器规约管理 Pods。与 Deployment 不同的是，StatefulSet 为每个 Pod 维护了一个有粘性的 ID。这些 Pod 是基于相同的规约来创建的，但是不能互相替换；无论如何调度，每个 Pod 都有一个永久不变的 ID。

如果用户希望使用存储卷为工作负载提供持久储存，可以使用 StatefulSet 作为解决方案的一部分。尽管 StatefulSet 中的单个 Pod 仍然可能出现故障，但持久的 Pod 标识符使得将现有卷与替换已失败 Pod 的新 Pod 相匹配变得更加容易。

### 使用 StatefulSet

StatefulSet 对于需要满足以下一个或多个需求的应用程序很有价值：

- 稳定的，唯一的网络标识符。
- 稳定的，持久的存储。
- 有序的，优雅的部署和扩缩。
- 有序的，自动的滚动更新。

上述需求中，稳定意味着 Pod （重新）调度的整个过程带有持久性质的。如果应用程序不需要任何稳定的标识符或有序的部署，删除或扩缩，则应该使用一组无状态的副本控制器提供的工作负载来部署应用程序，比如 Deployment 或者 ReplicaSet 可能更适合无状态应用部署的需要。

### 限制

WIP

### 组件

WIP

#### Pod 选择符 {#StatefulSetPodSelector}

WIP

#### 卷声明模板

WIP

#### 最短就绪秒数

WIP

### Pod 标识

WIP

#### 有序索引

WIP

#### 稳定的网络 ID

WIP

#### 稳定的存储

WIP

#### Pod 名称标签

WIP

### 部署与扩缩保证

WIP

#### Pod 管理策略

WIP

### 更新策略

WIP

### 滚动更新

WIP

#### 分区滚动更新

WIP

#### 最大不可用 Pod

WIP

#### 强制回滚

WIP

### PersistentVolumeClaim 保留

WIP

#### 副本数

WIP

## DaemonSet

DaemonSet 确保所有（或者部分）节点运行拷贝的 Pod。当节点被添加到集群时，Pods 也同样的被添加。当节点从集群中移除时，这些 Pods 则被垃圾回收。删除 DaemonSet 将会清理其创建的 Pods。

DaemonSet 的一些典型的用例：

- 在每个节点上运行集群守护进程
- 在每个节点上运行日志收集守护进程
- 在每个节点上运行监控守护进程

一种简单的用法是为每种类型的守护进程在所有节点上都启动一个 DaemonSet。一个稍微复杂的用法是为同一种守护进程部署多个 DaemonSet；每个具有不同的标志，并且对不同硬件类型具有不同的内存，CPU 要求。

### 编写 DaemonSet Spec

WIP

#### 创建 DaemonSet

WIP

#### 必须字段

WIP

#### Pod 模板 {#DaemonSetPodTemplate}

WIP

#### Pod 选择符

WIP

#### 仅在某些节点上运行 Pod

WIP

### Daemon Pods 如何被调度

WIP

#### 通过默认调度器调度

WIP

#### 污点和容忍度

WIP

### 与 DaemonSet 通信

WIP

### 更新 DaemonSet

WIP

### DaemonSet 替代方案

WIP

#### init 脚本 {#DaemonSetInitScripts}

WIP

#### 裸 Pod {#DaemonSetBarePods}

WIP

#### 静态 Pod {#DaemonSetStaticPods}

WIP

#### Deployments {#DaemonSetDeployment}

WIP

## Jobs

WIP

### 运行示例 Job

WIP

### 编写 Job 规约

WIP

#### Pod 模板 {#JobsPodTemplate}

WIP

#### Pod 选择符 {#JobsPodSelector}

WIP

#### Job 并行执行

WIP

#### 完成模式

WIP

### 处理 Pod 和容器失效

WIP

#### Pod 回退失效策略

WIP

### Job 终止与清理

WIP

### 自动清理完成的 Job

WIP

#### 已完成 Job 的 TTL 机制

WIP

### Job 模式

WIP

### 高级用法

WIP

#### 挂起 Job

WIP

#### 可变调度指令

WIP

#### 指定 Pod 选择符

WIP

#### 使用 Finalizer 追踪 Job

WIP

### 替代方案 {#JobsAlternatives}

WIP

#### 裸 Pod {#JobsBarePod}

WIP

#### 副本控制器

WIP

#### 单个 Job 启动控制器 Pod

WIP

## 已完成 Jobs 的自动清理

WIP

## CronJob

WIP

## ReplicationController

WIP
