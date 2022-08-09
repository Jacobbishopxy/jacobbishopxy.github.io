+++
title = "Rancher k8s cluster setup"
description = "An experimental record"
date = 2022-07-18

[taxonomies]
categories = ["Post"]
tags = ["k8s"]

[extra]
toc = true
+++

## Prerequisites

1. Config `/etc/hosts` by adding master & workers' IP addresses (optional). Here we use four machines for demonstration (master for etcd & control plane, and the rest for worker. Visit [Checklist for Production-Ready Clusters](https://rancher.com/docs/rancher/v2.6/en/cluster-provisioning/production/) for more information):

   ```txt
   192.168.50.140 k8s-master
   192.168.50.141 k8s-node1
   192.168.50.142 k8s-node2
   192.168.50.143 k8s-node3

   # /etc/hosts
   192.168.50.140 h194
   ```

1. Config machine name (optional):

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

1. Set timezone:

   ```sh
   sudo timedatectl set-timezone Asia/Shanghai
   ```

1. Turn off swap:

   ```sh
   sudo swapoff -a
   ```

## Kubectl

**Skip this step if using RKE2 & Rancher**, directly goto [RKE2](@/posts/2022-7-18-rancher-k8s-cluster-setup.md#RKE2).

Install these packages on all of your machines:

- `kubeadm`: the command to bootstrap the cluster
- `kubelet`: the component that runs on all of the machines in your cluster and does things like starting pods and containers
- `kubectl`: the command line util to talk to your cluster

1. Import gpg key. This step is very import especially lacking of a proxy server:

   ```sh
   sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg  https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg
   ```

   or by using tuna source:

   ```sh
   sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg  https://mirrors.tuna.tsinghua.edu.cn/kubernetes/apt/doc/apt-key.gpg
   ```

1. Create `/etc/apt/sources.list.d/kubernetes.list`. Another important step of setting up mirrors:

   ```sh
   deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://mirrors.aliyun.com/kubernetes/apt kubernetes-xenial main
   ```

   or by using tuna source:

   ```sh
   deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://mirrors.tuna.tsinghua.edu.cn/kubernetes/apt kubernetes-xenial main
   ```

1. Installation:

   ```sh
   sudo apt-get update
   # (instead of using Rancher, manual setup cluster by kubeadm)
   # sudo apt-get install -y kubelet kubeadm kubectl
   sudo apt-get install -y kubectl
   ```

1. Grant permission:

   If we see warnings as following:

   ```txt
   WARNING: Kubernetes configuration file is group-readable. This is insecure. Location: /home/xy/.kube/config
   WARNING: Kubernetes configuration file is world-readable. This is insecure. Location: /home/xy/.kube/config
   ```

   We can modify permission to solve it. The first line is read and write permission for users in the same group, while the second line is read permission for the rest:

   ```sh
   chmod g-rw ~/.kube/config
   chmod o-r ~/.kube/config
   ```

## Docker

Container runtime.

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

1. Enable docker start on boot

   ```sh
   sudo systemctl enable docker.service
   sudo systemctl enable containerd.service
   ```

   or disable:

   ```sh
   sudo systemctl disable docker.service
   sudo systemctl disable containerd.service
   ```

1. Check if docker can be run without root

   ```sh
   docker run hello-world
   ```

## RKE2 {#RKE2}

- [quick start](https://docs.rke2.io/install/quickstart/)

- [requirements](https://docs.rke2.io/install/requirements/)

- **[Ubuntu user skip this step]** If using CentOS instead of Ubuntu: According to [a known issue](https://docs.rke2.io/known_issues/#networkmanager), config NetworkManager before install RKE2 (otherwise reboot first):

  Create a config file called `rke2-canal.conf` in `/etc/NetworkManger/conf.d`:

  ```txt
  [keyfile]
  unmanaged-devices=interface-name:cali*;interface-name:flannel*
  ```

  then reload:

  ```sh
  systemctl reload NetworkManager
  ```

### Server Node Installation {#RKE2ServerNodeInstallation}

1. Switch to root user.

1. Run the installer: `curl -sfL https://get.rke2.io | sh -`

1. Enable the rke2-server service: `systemctl enable rke2-server.service`

1. Start the service: `systemctl start rke2-server.service`

1. Follow the logs (optional): `journalctl -u rke2-server -f`

{% blockquote(class="blockquote-note") %}
After running this installation:

- The `rke2-server` service will be installed. The `rke2-server` service will be configured to automatically restart after node reboots or if the process crashes or is killed.
- Additional utilities will be installed at `/var/lib/rancher/rke2/bin/`. They include: `kubectl`, `crictl`, and `ctr`. Note that these are not on your path by default.
- Two cleanup scripts will be installed to the path at `/usr/local/bin/rke2`. They are: `rke2-killall.sh` and `rke2-uninstall.sh`.
- A kubeconfig file will be written to `/etc/rancher/rke2/rke2.yaml`.
- A token that can be used to register other server or agent nodes will be created at `/var/lib/rancher/rke2/server/node-token`

{% end %}

### Agent Node Installation

1. Switch to root user.

1. Run the installer: `curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE="agent" sh -`

1. Enable the rke2-agent service: `systemctl enable rke2-agent.service`

1. Configure the rke2-agent service:

   ```sh
   mkdir -p /etc/rancher/rke2/
   vim /etc/rancher/rke2/config.yaml
   ```

   Content:

   ```yaml
   server: https://<server>:9345
   token: <token from server node>
   ```

1. Start the service: `systemctl start rke2-agent.service`

1. Follow the logs (optional): `journalctl -u rke2-agent -f`

### Cluster Access

As mentioned [above](@posts/2022-7-18-rancher-k8s-cluster-setup.md#RKE2ServerNodeInstallation), kubeconfig file is stored at `/etc/rancher/rke2/rke2.yaml`.

Leverage the KUBECONFIG environment variable:

```sh
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
kubectl get pods --all-namespaces
helm ls --all-namespaces
```

Or specify the location of the kubeconfig file in the command:

```sh
kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml get pods --all-namespaces
helm --kubeconfig /etc/rancher/rke2/rke2.yaml ls --all-namespaces
```

Accessing the Cluster from Outside with kubectl:

Copy `/etc/rancher/rke2/rke2.yaml` on your machine located outside the cluster as `~/.kube/config`. Then replace `127.0.0.1` with the IP or hostname of your RKE2 server. `kubectl` can now manage your RKE2 cluster.

## Helm

> Helm is a tool for managing packages of pre-configured Kubernetes resources. These packages are known as Helm charts.
>
> Use Helm to:
>
> - Find and use popular software packaged as Kubernetes charts
> - Share your own applications as Kubernetes charts
> - Create reproducible builds of your Kubernetes applications
> - Intelligently manage your Kubernetes manifest files
> - Manage releases of Helm packages

Official Helm [document](https://helm.sh/docs/) and Rancher's Helm [document](https://rancher.com/docs/k3s/latest/en/helm/).

1. Installation:

   ```sh
   curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
   chmod 700 get_helm.sh
   ./get_helm.sh
   ```

1. Initialize a Helm Chart Repository:

   ```sh
   helm repo add bitnami https://charts.bitnami.com/bitnami
   ```

   then we can list the charts we can install:

   ```sh
   helm search repo bitnami
   ```

## Rancher

> **Why Rancher?**
>
> Rancher is a complete software stack for teams adopting containers. It addresses the operational and security challenges of managing multiple Kubernetes clusters across any infrastructure, while providing DevOps teams with integrated tools for running containerized workloads.

### Installation

[Install by helm](https://rancher.com/docs/rancher/v2.6/en/installation/install-rancher-on-k8s/)

1. Add the Helm chart repo: `helm repo add rancher-stable https://releases.rancher.com/server-charts/stable`

1. Create a namespace for Rancher: `kubectl create namespace cattle-system`

1. Install cert-manager:

   ```sh
   kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.7.1/cert-manager.crds.yaml
   ```

   Add the Jetstack Helm repository:

   ```sh
   helm repo add jetstack https://charts.jetstack.io
   ```

   Update your local Helm chart repository cache:

   ```sh
   helm repo update
   ```

   Install the cert-manager Helm chart:

   ```sh
   helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --version v1.7.1
   ```

   Check cert-manager:

   ```sh
   kubectl get pods --namespace cert-manager
   ```

1. Install Rancher, notice because of going through Nginx, add `--set tls=external`

   ```sh
   helm install rancher rancher-stable/rancher --namespace cattle-system --set hostname=<DNS name> --set bootstrapPassword=<your secret password> --set tls=external
   ```

   Wait for Rancher to be rolled out:

   ```sh
   kubectl -n cattle-system rollout status deploy/rancher
   ```

1. According to [this](https://docs.rke2.io/networking/#nginx-ingress-controller), modify RKE2 Nginx config `/var/lib/rancher/rke2/server/manifests/rke2-ingress-nginx-config.yaml`:

   ```yaml
   apiVersion: helm.cattle.io/v1
   kind: HelmChartConfig
   metadata:
   name: rke2-ingress-nginx
   namespace: kube-system
   spec:
   valuesContent: |-
     controller:
        config:
        use-forwarded-headers: "true"
   ```

   and restart:

   ```sh
   systemctl restart
   ```

1. Verify that the Rancher server is successfully deployed:

   ```sh
   kubectl -n cattle-system rollout status deploy/rancher
   ```

### Development Clusters

**This case is only for development, do not use it in production.**

1. Start a rancher web server:

   ```sh
   sudo docker run --privileged -d --restart=unless-stopped -p 80:80 -p 443:443 rancher/rancher:stable
   ```

1. Visit web `https://192.168.50.140` (according to the host IP)

1. Copy `docker logs <container ID> 2>&1 | grep "Bootstrap Password:"` to terminal (get container ID by `docker ps`), by executing this command we will get `Bootstrap Password`, and paste password back to website

1. Click `☰` button at the website's top-left, then `Cluster Management`, then `Create` button on the top-right, choose `Custom`

1. After enter your `Cluster Name`, keep everything default, click `Next` and in `Node Options`, select `etcd` and `Control Plane` for `140` and the rest `141`, `142` and `143` as `Worker`.

Accessing clusters with `kubectl`:

1. Log into Rancher. From the Global view, open the cluster that you want to access with kubectl.
1. Click `Copy KubeConfig to Clipboard` button.
1. Paste the contents into a new file on your local computer. Move the file to ~/.kube/config. (Note: The default location that kubectl uses for the kubeconfig file is ~/.kube/config, but you can use any directory and specify it using the --kubeconfig flag, as in this command: kubectl --kubeconfig /custom/path/kube.config get pods)
1. Set global config `echo "export KUBECONFIG=~/.kube/config" >> ~/.bash_profile` and `source ~/.bash_profile`
1. Now we can use `kubectl version` or `kubectl get nodes` to check whether configuration is successful or not

## Resolutions

- In case of no `root` user when installing RKE2, Ubuntu initialize `root` user:

  ```sh
  # init
  sudo passwd root

  # change password expire info
  sudo passwd -l root

  # switch
  sudo -s -H
  ```

- Docker images mirror (optional):

  execute `vim /etc/docker/daemon.json`, add:

  ```json
  { "registry-mirrors": ["https://docker.mirrors.ustc.edu.cn"] }
  ```

  then reload services:

  ```sh
  sudo systemctl daemon-reload
  sudo systemctl restart docker
  ```

- Clear all containers and images when [deployment failed](https://github.com/rancher/rancher/issues/21926):

  ```sh
  docker stop $(docker ps -aq)
  docker rm $(docker ps -aq)
  docker system prune -f
  docker volume rm $(docker volume ls -q)
  docker image rm $(docker image ls -q)
  sudo rm -rf /etc/ceph \
        /etc/cni \
        /etc/kubernetes \
        /opt/cni \
        /opt/rke \
        /run/secrets/kubernetes.io \
        /run/calico \
        /run/flannel \
        /var/lib/calico \
        /var/lib/etcd \
        /var/lib/cni \
        /var/lib/kubelet \
        /var/lib/rancher/rke/log \
        /var/log/containers \
        /var/log/pods \
        /var/run/calico
  ```

  Note that calling `rm -rf ...` is very useful, when encounter `etcd connection refused` problem. This usually happened when cached some previous cluster's residual files.

- `rm: cannot remove '/var/lib/kubelet/pods/<pods-id>': Device or resource busy`

  Simply by `umount` command:

  ```sh
  sudo umount /var/lib/kubelet/pods/<pods-id>
  ```

  Or `sudo reboot` then execute commands above

- Failed to bring up Etcd Plane: etcd cluster is unhealthy. [solution](https://blog.csdn.net/xtjatswc/article/details/108558156)

- `node-role.kubernetes.io/controlplane=true:NoSchedule` means no pod will be able to schedule onto this node, unless it has a matching toleration. To remove this taint: `kubectl taint nodes node1 key1=value1:NoSchedule-`. In our case, this taint is normal on the master node, since we only setup one node for `etcd` and `control plane`. Hence, no need to remove this taint.

- `node-role.kubernetes.io/etcd=true:NoExecute` same as above.
