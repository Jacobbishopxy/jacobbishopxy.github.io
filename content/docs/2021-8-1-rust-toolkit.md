+++
title="Rust Toolkit"
description="Useful cargo tools"
date=2021-08-01

[taxonomies]
categories = ["Doc"]
tags = ["Rust"]
+++

## Rust

- Installation:

  ```sh
  curl https://sh.rustup.rs -sSf | sh
  ```

- [Optional] Toolchain and rustup mirrors: `vim ~/.bashrc` then `source ~/.bashrc`

  ```txt
  export RUSTUP_DIST_SERVER=https://mirrors.ustc.edu.cn/rust-static
  export RUSTUP_UPDATE_ROOT=https://mirrors.ustc.edu.cn/rust-static/rustup
  ```

  or

  ```txt
  export RUSTUP_DIST_SERVER=https://mirrors.tuna.tsinghua.edu.cn/rustup
  ```

  or

  ```txt
  RUSTUP_DIST_SERVER=https://mirrors.sjtug.sjtu.edu.cn/rust-static/
  ```

- [Optional] Cargo mirrors: `vim ~/.cargo/config`

  ```txt
  [source.crates-io]
  replace-with = 'rsproxy'

  [source.rsproxy]
  registry = "https://rsproxy.cn/crates.io-index"

  [source.tuna]
  registry = "https://mirrors.tuna.tsinghua.edu.cn/git/crates.io-index.git"

  [source.ustc]
  registry = "git://mirrors.ustc.edu.cn/crates.io-index"

  [source.sjtu]
  registry = "https://mirrors.sjtug.sjtu.edu.cn/git/crates.io-index"
  ```

## Cargo

Prerequisites for Ubuntu:

```sh
sudo apt install pkg-config
sudo apt install libssl-dev
sudo apt install build-essential
```

- [cargo-update](https://crates.io/crates/cargo-update): checking and applying updates to installed executables

  ```sh
  cargo install cargo-update
  ```

- [cargo-edit](https://crates.io/crates/cargo-edit): allow add/remove/upgrade dependencies by modifying `Cargo.toml`

  ```sh
  cargo install cargo-edit
  ```

- [cargo-make](https://crates.io/crates/cargo-make): Rust task runner and build tool

  ```sh
  cargo install --force cargo-make
  ```
