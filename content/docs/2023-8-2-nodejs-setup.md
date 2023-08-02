+++
title = "NodeJS setup"
description = "Nvm + Npm"
date = 2023-08-02

[taxonomies]
categories = ["Post"]
tags = ["Js"]
+++

## Nvm

```sh
git clone git@github.com/creationix/nvm.git .nvm
cd .nvm
git checkout v0.39.4
```

Optional, saving nvm into `.bashrc`:

```sh
...
source ~/.nvm/nvm.sh
...
```

```sh
source ~/.bashrc
```

Check NodeJS version:

```sh
nvm ls
```

Install the latest stable version:

```sh
nvm install stable
```

## Npm

Check Npm version

```sh
npm -v
```

Update, and install `yarn`

```sh
npm install -g npm
npm install -g yarn
```
