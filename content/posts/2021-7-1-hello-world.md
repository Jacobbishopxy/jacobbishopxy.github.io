+++
title = "Hello World!"
date = 2021-07-01

[taxonomies]
categories = ["Post"]
tags = ["Rust"]
+++

Hello everyone :wave:! This is the first post I made, and I hope I can persistently record my thoughts through my blog!

This blog is powered by [Zola](https://github.com/getzola/zola). Want to paly with Zola? Please follow the steps below.

## Prerequisites

- [Github cli](https://cli.github.com/): Optional
- [Rust](https://www.rust-lang.org/): Required

## Installation

- Make sure `libsass` is installed:

  ```sh
  sudo apt-get install libsass-dev
  ```

- Use Github cli to clone repo:

  ```sh
  gh repo clone getzola/zola

  # or by git clone
  git clone git@github.com:getzola/zola.git
  ```

- Build Rust binary executable:

  ```sh
  cd zola
  cargo build --release
  ```

- Move to user bin folder:

  ```sh
  mv ./target/release/zola ~/.local/bin/zola
  ```

- (Optional) If `.local/bin` is not in your path:

  ```sh
  vim ~/.bashrc
  ```

  and add this line:

  ```.bashrc
  export PATH=$PATH:~/.local/bin
  ```

  then:

  ```sh
  source ~/.bashrc
  ```

- Check installation:

  ```sh
  zola --help
  ```

## Setup

- Project init:

  ```sh
  zola init my-blog
  ```

- Select a [theme](https://www.getzola.org/themes/) (I chose `DeepThought`):

  ```sh
  git clone git@github.com:RatanShreshtha/DeepThought.git themes/DeepThought
  ```

## Deploy

Please check [the official instruction](https://www.getzola.org/documentation/deployment/github-pages/).
