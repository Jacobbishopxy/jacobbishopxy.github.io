+++
title="Docker-desktop k8s Setup"
description="k8s starting"
date=2022-07-03

[taxonomies]
categories = ["Doc"]
tags = ["k8s"]
+++

Docker desktop setup Kubernetes as a dev environment.

## Start up

Starting up from this [repo](https://github.com/AliyunContainerService/k8s-for-docker-desktop), we use image mirrors without any proxy setup.

## Use cases

### Spark

[Docker package](https://github.com/bitnami/bitnami-docker-spark)

Pre-pull image in case of k8s pulling timeout:

```sh
docker pull docker.io/bitnami/spark:3.3.0-debian-11-r2
```

```txt
** Please be patient while the chart is being deployed **

1. Get the Spark master WebUI URL by running these commands:

  kubectl port-forward --namespace default svc/my-spark-master-svc 80:80
  echo "Visit http://127.0.0.1:80 to use your application"

2. Submit an application to the cluster:

  To submit an application to the cluster the spark-submit script must be used. That script can be
  obtained at https://github.com/apache/spark/tree/master/bin. Also you can use kubectl run.

  export EXAMPLE_JAR=$(kubectl exec -ti --namespace default my-spark-worker-0 -- find examples/jars/ -name 'spark-example*\.jar' | tr -d '\r')

  kubectl exec -ti --namespace default my-spark-worker-0 -- spark-submit --master spark://my-spark-master-svc:7077 \
    --class org.apache.spark.examples.SparkPi \
    $EXAMPLE_JAR 5

** IMPORTANT: When submit an application from outside the cluster service type should be set to the NodePort or LoadBalancer. **

** IMPORTANT: When submit an application the --master parameter should be set to the service IP, if not, the application will not resolve the master. **
```
