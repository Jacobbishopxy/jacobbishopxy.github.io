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

WIP

#### downwardAPI

WIP

#### emptyDir

WIP

#### hostPath

WIP

#### local

WIP

#### persistentVolumeClaim

WIP

#### projected

WIP

### 使用 subPath

WIP

### 资源

WIP

### 树外卷

WIP

### 插件

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

## 特定于节点的卷限制 Node-specific Volume Limits

WIP

## 卷健康监测 Volume Health Monitoring

WIP
