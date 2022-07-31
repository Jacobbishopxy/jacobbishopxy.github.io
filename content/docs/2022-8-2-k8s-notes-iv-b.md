+++
title="K8s 笔记 (IV) 下"
description="工作负载（工作负载资源）"
date=2022-08-02

[taxonomies]
categories = ["Doc"]
tags = ["k8s"]

[extra]
toc = true
+++

## 负载资源

### Deployments

一个*Deployment*为 Pods 与 ReplicaSets 提供了声明式的更新。

在一个 Deployment 中用户描述一个*期望的状态*，接着 Deployment 控制器通过速度控制改变现有状态至期望状态。用户可以定义 Deployments 来创建新的 ReplicaSets，或者移除现有的 Deployments 并通过新的 Deployments 继承它们的资源。

> **注意：**
> 不要管理由 Deployment 所属的 ReplicaSets。

#### 使用案例

以下是 Deployments 的典型使用案例：

- [创建一个 Deployment 以将 ReplicaSet 上线](@/docs/2022-8-2-k8s-notes-iv-b.md#CreatingADeployment)。ReplicaSet 在后台创建 Pods。检查上线状态确认其成功与否。

- [通过更新 Deployment 的 Pod 模版声明一个 Pods 的新状态](@/docs/2022-8-2-k8s-notes-iv-b.md#UpdatingADeployment)。一个新的 ReplicaSet 被创建，并且 Deployment 控速从旧的 ReplicaSet 移动 Pods 至新的。每个新的 ReplicaSet 都会更新 Deployment 的修订版本。

- [回滚到较早之前的 Deployment 版本](@/docs/2022-8-2-k8s-notes-iv-b.md#RollingBackADeployment)，如果当前状态的 Deployment 并不稳定。每次回滚都会更新 Deployment 的修订版本。

- [拓展 Deployment 规模用以承担更多负载](@/docs/2022-8-2-k8s-notes-iv-b.md#ScalingADeployment)。

- [暂停 Deployment](@/docs/2022-8-2-k8s-notes-iv-b.md#PausingAndResumingADeployment) 用以修复若干 Pod 模板，并恢复开始一个新的上线过程。

- [使用 Deployment 状态](@/docs/2022-8-2-k8s-notes-iv-b.md#DeploymentStatus)判断上线过程是否出现停滞。

- [清理较旧的不再需要的 ReplicaSet](@/docs/2022-8-2-k8s-notes-iv-b.md#CleanUpPolicy)。

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

#### 更新 Deployment {#UpdatingADeployment}

WIP

#### 回滚 Deployment {#RollingBackADeployment}

WIP

#### 拓展 Deployment {#ScalingADeployment}

WIP

#### 暂停和恢复 Deployment 的上线过程 {#PausingAndResumingADeployment}

WIP

#### Deployment 状态 {#DeploymentStatus}

WIP

#### 清理策略 {#CleanUpPolicy}

WIP

#### 金丝雀部署

WIP

#### 编写 Deployment 规约

WIP

### ReplicaSet

WIP

### StatefulSets

WIP

### DaemonSet

WIP

### Jobs

WIP

### 已完成 Jobs 的自动清理

WIP

### CronJob

WIP

### ReplicationController

WIP
