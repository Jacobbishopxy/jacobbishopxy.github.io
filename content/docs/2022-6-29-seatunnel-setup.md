+++
title="SeaTunnel Setup"
description="Standalone mode setup"
date=2022-06-29

[taxonomies]
categories = ["Doc"]
tags = []
+++

SeaTunnel standalone mode setup.

## Spark

Choose a spark version from [here](https://dlcdn.apache.org/spark) to download, for instance (currently SeaTunnel only accepts Spark 2.0):

```sh
wget https://downloads.apache.org/spark/spark-2.4.8/spark-2.4.8-bin-hadoop2.7.tgz
```

Next, extract the saved archive using `tar`:

```sh
tar xvf spark-*
```

And `mv` command:

```sh
sudo mv spark-* /opt/spark
```

Now we are going to configure Spark environment using `echo`:

```sh
echo "export SPARK_HOME=/opt/spark" >> ~/.profile
echo "export PATH=$PATH:$SPARK_HOME/bin:$SPARK_HOME/sbin" >> ~/.profile
echo "export PYSPARK_PYTHON=/usr/bin/python3" >> ~/.profile
```

and load it:

```sh
source ~/.profile
```

We can now start standalone Spark Master Server by:

```sh
cd /opt/spark/sbin
./start-master.sh
```

Then we shall see Spark web user interface on [http://localhost:8080/](http://localhost:8080/).

Next, we need to have a slave server to run:

```sh
./start-slave.sh spark://localhost:7077
```

To test Spark shell:

```sh
spark-shell
```

`:q` to exit Scala:

```scala
:q
```

Other basic commands:

- `start-master.sh`

- `stop-master.sh`

- `stop-slave.sh`

- `start-all.sh`

- `stop-all.sh`

**IMPORTANT!**

If we're running Ubuntu on WSL, and we may see `localhost: ssh: connect to host localhost port 22: Connection refused` this error while trying to start a spark worker, we shall generate a new ssh key for localhost. According to [this](https://stackoverflow.com/a/60198221):

If openssh-server not installed:

```sh
sudo apt-get upgrade
sudo apt-get update
sudo apt-get install openssh-server
sudo service ssh start
```

Take the following steps to enable `ssh` for localhost:

```sh
cd ~/.ssh
ssh-keygen                          # generate a public/private rsa key pair; use the default options
cat id_rsa.pub >> authorized_keys   # to append the key to the authorized_keys file
chmod 640 authorized_keys           # to set restricted permissions
sudo service ssh restart            # to pickup recent changes
ssh localhost
```

## SeaTunnel

Download SeaTunnel:

```sh
export version="2.1.2"
wget "https://archive.apache.org/dist/incubator/seatunnel/${version}/apache-seatunnel-incubating-${version}-bin.tar.gz"
tar -xzvf "apache-seatunnel-incubating-${version}-bin.tar.gz"
```

Test demo (`spark.streaming.conf.template` only works on Spark cluster):

```sh
cd "apache-seatunnel-incubating-${version}"
./bin/start-seatunnel-spark.sh \
--master local[4] \
--deploy-mode client \
--config ./config/spark.batch.conf.template
```

## Docker

[A simple docker demo](https://github.com/Jacobbishopxy/dockerfile/tree/master/sea-tunnel)

## Use case

WIP

## References

- [install spark on ubuntu](https://phoenixnap.com/kb/install-spark-on-ubuntu)
- [spark manual](https://spark.apache.org/docs/latest/spark-standalone.html#installing-spark-standalone-to-a-cluster)
