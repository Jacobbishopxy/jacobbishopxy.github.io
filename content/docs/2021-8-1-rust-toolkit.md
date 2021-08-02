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

- Proxy: `~/.cargo/config`

  ```config
  [source.crates-io]
  replace-with = 'rsproxy'

  [source.rsproxy]
  registry = "https://rsproxy.cn/crates.io-index"
  ```

## Cargo

- [cargo-update](https://crates.io/crates/cargo-update): checking and applying updates to installed executables

  ```sh
  sudo apt install pkg-config
  sudo apt install libssl-dev
  sudo apt install build-essential
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
