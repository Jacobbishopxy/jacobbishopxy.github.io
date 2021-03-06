+++
title = "Microservice Preparation"
description = "React + Golang + Grpc + Rust + Redis + Mongo"
date = 2021-07-22

[taxonomies]
categories = ["Post"]
tags = ["Js", "Go", "Grpc", "Rust"]

+++

{{ image(src="/images/rustgo.jpg", alt="Rust + Go", height="250px") }}

Hello everyone :wave:, today I'm going to start a new project demonstrating how to build a microservices system. `React`, `Golang`, `Grpc`, `Rust`, `Redis`, `Mongo` and maybe more will be used in this scenario. The reason why I choose these tech stacks is because I really like Golang and Rust, and I wish I can use them to enhance my projects in the real work, which is done by `Python` and `NodeJs`.

Obviously, for quick production's sake, `Python` and `NodeJs` are very friendly and easy to use, but as the time goes when the whole system is getting larger and larger, it starts getting out of control. There are many reasons I have to refactor my project, such as single threaded backend services, loose project management, weak language type and etc, but for now these issuses are not what we ought to concern. Let's go back to our topic and before we get our hands wet, there are few prerequisites that we need to notice.

Before we start, I have to mention that due to my job requirement, which is always dealing with Office softwares, I have to use Windows as my working environment. Therefore, choosing `WSL2(Ubuntu) + Windows Docker Desktop + VsCode` as my dev env can eliminate cross-platform headache.

## Prerequisites

### WSL

Please check [my previous post](@/docs/2021-7-2-wsl-setup.md).

### VsCode

Extensions:

**eslint**:

> Integrates ESLint into VS Code

**go**:

> The VS Code Go extension provides rich language support for the Go programming language.

**rust-analyzer**:

> Provides support for rust-analyzer: novel LSP server for the Rust programming language.

**clang-format**:

> Clang-Format is a tool to format C/C++/Java/JavaScript/Objective-C/Objective-C++/Protobuf code. It can be configured with a config file within the working folder or a parent folder.

And don't forget to install `clang-format` in your operation system:

```sh
sudo apt-get install clang-format
```

**vscode-proto3**:

> Protobuf 3 support for Visual Studio Code

### NPM or Yarn

Prerequisite for JavaScript/TypeScript is very simple and no pitfall.

```sh
sudo apt update
sudo apt upgrade -y
sudo apt-get install curl
curl -sL https://deb.nodesource.com/setup_16.x | sudo -E bash -
sudo apt-get install nodejs
sudo apt install npm
sudo npm i -g npm
sudo npm i -g yarn
```

### Rustc and Cargo

Here is my favorite part: the simplest installation ever! Decent and tidy!

```sh
curl https://sh.rustup.rs -sSf | sh

source $HOME/.cargo/env
```

And that's it! You can check rustup, rustc and cargo version by:

```sh
rustup --version

rustc --version

cargo --version
```

### Go

A little bit tricky here, because for some part of the real world, proxy is a must.

```sh
curl -O https://storage.googleapis.com/golang/go1.17.linux-amd64.tar.gz

tar -xvf go1.17.linux-amd64.tar.gz

# optional, if you have a previous installed version
sudo rm -rf /usr/local/go

sudo mv go /usr/local

rm go1.17.linux-amd64.tar.gz

# optional, if you have already added GOPATH to `.bashrc`
sudo vim ~/.bashrc
```

And add these two lines at the end of the file:

```.bashrc
export GOPATH=$HOME/go
export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin
```

Then:

```sh
source ~/.bashrc

go version
```

Set proxy:

```sh
go env -w GOPROXY=https://goproxy.io,direct
```

After VsCode **go** extension installed, `ctrl + shift + p` open commands and type `go: install/update tools`. Select all and update.

### GRPC

The trickiest part now comes. We need a code generate tool called `protoc`, which will be used to generate our Golang code.

Thanks to [google.github.io/proto-lens](http://google.github.io/proto-lens/installing-protoc.html), who makes the whole process way easier. By simply using `sudo apt install -y protobuf-compiler` command, we can not install the latest version. And moreover, it could drive you crazy, because later on you would find that dependencies like `import "google/protobuf/timestamp.proto";` cannot be found!. This is because the default folder is not in the right position.

To install `protoc` cli, visit [protobuf release page](https://github.com/protocolbuffers/protobuf) and choose the latest one (the current latest ver. is `3.17.3`), then:

```sh
PROTOC_ZIP=protoc-3.17.3-linux-x86_64.zip

curl -OL https://github.com/protocolbuffers/protobuf/releases/download/v3.17.3/$PROTOC_ZIP

sudo unzip -o $PROTOC_ZIP -d /usr/local bin/protoc

sudo unzip -o $PROTOC_ZIP -d /usr/local 'include/*'

rm -f $PROTOC_ZIP

sudo chown -R $USER /usr/local/include/google/

sudo chmod +x /usr/local/bin/protoc
```

Notice the last two lines may not be required, but in case of `permission denied` occurred, please use them.

### Docker

In order to quickly setup dev tools, such as Redis, MongoDB, Mongo Express and etc, we choose to use Docker desktop. Its' installation is also simple and neat: just follow [the official website](https://www.docker.com/products/docker-desktop) you can get a WSL based docker desktop on Windows.

## Conclusion

Ok, I think we have done a lot today and I hope you like it. The next section will be the design of this project. See you soon :heart:
