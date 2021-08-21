+++
title="WSL setup"
description="Setup WSL on Windows"
date=2021-07-01

[taxonomies]
categories = ["Doc"]
+++

## WSL and Ubuntu download

Please follow [the official documentation](https://docs.microsoft.com/en-us/windows/wsl/install-win10).

## Move Ubuntu to another driver

This is an optional step, in case of C driver space insufficient (make sure you have already create directories as following):

```cmd
wsl --export Ubuntu-20.04 d:\tmp\ubuntu.tar
wsl --unregister Ubuntu-20.04
wsl --import Ubuntu-20.04 d:\wsl\Ubuntu-20.04 d:\tmp\ubuntu.tar
```

## Modify Windows `settings.json`

To modify Ubuntu's starting directory, we can open Windows terminal, and you'll see **Open JSON file** button, click it and add a new line called `startingDirectory` as below:

```json
{
    "guid": ...,
    "hidden": false,
    "name": "Ubuntu-20.04",
    "source": "Windows.Terminal.Wsl",
    "startingDirectory": "//wsl$/Ubuntu-20.04/home/<username>"
}
```

## Setup `wsl.conf`

1. Create a new file called `wsl.conf`:

   ```sh
   sudo vim /etc/wsl.conf
   ```

1. Inside your file (please modify the username):

   ```conf
   # Set default user, otherwise sign as root
   [user]
   default=<username>

   # Let’s enable extra metadata options by default
   [automount]
   enabled = true
   root = /mnt/
   options = "metadata,umask=22,fmask=11"
   mountFsTab = false

   #Let’s enable DNS – even though these are turned on by default, we’ll specify here just to be explicit.
   [network]
   generateHosts = true
   generateResolvConf = true

   #All windows program shoulbe be normally run in wsl. great!
   [interop]
   enable = true
   appendWindowsPath = true
   ```

1. Save your file and grant permission:

   ```sh
   sudo chmod -R 775 /etc/wsl.conf
   ```

## Setup Git

```sh
git config --global user.name <Your name>

git config --global user.email <Your email>
```

If the following error occurred:

> Warning: Permanently added 'github.com,XX.XXX.XXX.XXX' (RSA) to the list of known hosts.

Open the `hosts` file:

```sh
vim /etc/hosts
```

Add add the line:

```sh
XX.XXX.XXX.XXX  github.com
```

## Setup Github Cli

A shortcut:

```sh
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-key C99B11DEB97541F0
sudo apt-add-repository https://cli.github.com/packages
sudo apt update
sudo apt install gh
```

Then authentication (follow up the indication provided by gh):

```sh
gh auth login
```
