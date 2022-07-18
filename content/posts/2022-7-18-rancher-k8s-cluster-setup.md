+++
title = "Rancher k8s cluster setup"
description = "An experimental attempt"
date = 2022-07-14

[taxonomies]
categories = ["Post"]
tags = ["k8s"]

[extra]
toc = true
+++

## kubectl

Install these packages on all of your machines (only needs `kubectl` if we use rancher):

- `kubeadm`: the command to bootstrap the cluster
- `kubelet`: the component that runs on all of the machines in your cluster and does things like starting pods and containers
- `kubectl`: the command line util to talk to your cluster

1. config `/etc/hosts` by adding master & workers' IP addresses:

   ```txt
   192.168.50.140 k8s-master
   192.168.50.141 k8s-node1
   192.168.50.142 k8s-node2
   192.168.50.143 k8s-node3
   ```

1. config machine name:

   ```sh
   ## master
   sudo hostnamectl set-hostname "k8s-master"
   exec bash

   ## node1
   sudo hostnamectl set-hostname "k8s-node1"
   exec bash

   ## node2
   sudo hostnamectl set-hostname "k8s-node2"
   exec bash

   ## node3
   sudo hostnamectl set-hostname "k8s-node3"
   exec bash
   ```

1. turn off swap:

   ```sh
   sudo swapoff -a
   ```

1. import gpg key:

   ```sh
   sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg  https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg
   ```

   or by using tuna source:

   ```sh
   sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg  https://mirrors.tuna.tsinghua.edu.cn/kubernetes/apt/doc/apt-key.gpg
   ```

1. create `/etc/apt/sources.list.d/kubernetes.list`:

   ```sh
   deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://mirrors.aliyun.com/kubernetes/apt kubernetes-xenial main
   ```

   or by using tuna source:

   ```sh
   deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://mirrors.tuna.tsinghua.edu.cn/kubernetes/apt kubernetes-xenial main
   ```

1. install all:

   ```sh
   sudo apt-get update
   sudo apt-get install -y kubelet kubeadm kubectl
   ```

## docker

1. Uninstall old versions

   ```sh
   sudo apt-get remove docker docker-engine docker.io containerd runc
   ```

1. Update the apt package index and install packages to allow apt to use a repository over HTTPS

   ```sh
   sudo apt-get update
   sudo apt-get install \
     ca-certificates \
     curl \
     gnupg \
     lsb-release
   ```

1. Add Docker’s official GPG key

   ```sh
   sudo mkdir -p /etc/apt/keyrings
   curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
   ```

1. Set up the repository

   ```sh
   echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
   ```

1. Install docker engine

   ```sh
   sudo apt-get update
   sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin
   ```

1. Create the docker group if it does not exist

   ```sh
   sudo groupadd docker
   ```

1. Add your user to the docker group.

   ```sh
   sudo usermod -aG docker $USER
   ```

1. Run the following command or Logout and login again and run (that doesn't work you may need to reboot your machine first)

   ```sh
   newgrp docker
   ```

1. Check if docker can be run without root

   ```sh
   docker run hello-world
   ```

## rancher

1. start a rancher web server:

   ```sh
   sudo docker run --privileged -d --restart=unless-stopped -p 80:80 -p 443:443 rancher/rancher:stable
   ```
