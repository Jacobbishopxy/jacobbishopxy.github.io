+++
title="Ubuntu22 clang and clangd"
description="Upgrade clang & clangd to 20"
date=2025-09-23

[taxonomies]
categories = ["Doc"]
+++

## clang

```sh
# Add LLVM repository
wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | sudo apt-key add -
sudo apt-add-repository "deb http://apt.llvm.org/$(lsb_release -cs)/ llvm-toolchain-$(lsb_release -cs)-20 main"
sudo apt-get update

# Install Clang 20
sudo apt-get install clang-20 clang-tools-20 clang-format-20 clangd-20 lld-20 lldb-20 llvm-20-dev

# Set as default
sudo update-alternatives --install /usr/bin/clang clang /usr/bin/clang-20 100
sudo update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-20 100
```

## clangd

```sh
wget https://github.com/clangd/clangd/releases/download/20.1.8/clangd-linux-20.1.8.zip
sudo unzip clangd-linux-20.1.8.zip -d /opt/
```

## vscode

.vscode/settings.json:

```json
{
    "clangd.path": "/opt/clangd_20.1.8/bin/clangd",
    "clangd.arguments": [
        "--compile-commands-dir=${workspaceFolder}/build",
        "--completion-style=detailed",
        "--header-insertion=never",
        "--background-index=false"
    ],
    ...
}
```
