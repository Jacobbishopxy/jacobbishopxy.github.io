+++
title="GRPC Toolkit"
description="GRPC dev's prerequisites"
date=2021-07-26

[taxonomies]
categories = ["Doc"]
tags = ["Grpc"]

[extra]
toc = true
+++

## Protoc

> Protocol Buffer Compiler

```sh
PROTOC_ZIP=protoc-3.17.3-linux-x86_64.zip

curl -OL https://github.com/protocolbuffers/protobuf/releases/download/v3.17.3/$PROTOC_ZIP

sudo unzip -o $PROTOC_ZIP -d /usr/local bin/protoc

sudo unzip -o $PROTOC_ZIP -d /usr/local 'include/*'

rm -f $PROTOC_ZIP

sudo chown -R $USER /usr/local/include/google/

sudo chmod +x /usr/local/bin/protoc

protoc --version
```

## Evans

> Evans: more expressive universal gRPC client

```sh
curl -OL https://github.com/ktr0731/evans/releases/download/0.10.0/evans_linux_amd64.tar.gz

tar zxvf evans_linux_amd64.tar.gz

sudo mv evans /usr/local/bin/

rm evans_linux_amd64.tar.gz

evans -v
```
