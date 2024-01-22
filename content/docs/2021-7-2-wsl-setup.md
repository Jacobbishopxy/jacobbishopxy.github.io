+++
title="WSL setup"
description="Setup WSL on Windows"
date=2021-07-02
updated=2023-02-16

[taxonomies]
categories = ["Doc"]
+++

## WSL and Ubuntu download

One line command: `wsl --install`.

For futher detailed info, visit [the official documentation](https://docs.microsoft.com/en-us/windows/wsl/install-win10).

## Install Windows Terminal

Please follow [this step](https://learn.microsoft.com/en-us/windows/terminal/install).

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
    "commandline": "wsl ~ -d Ubuntu",
    "hidden": false,
    "name": "Ubuntu",
    "source": "Windows.Terminal.Wsl",
    "startingDirectory": "~"
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

## New user

1. Add user:

   ```sh
   sudo adduser jacob
   ```

   remove user:

   ```sh
   sudo deluser jacob
   ```

1. Update sudoers

   ```sh
   sudo -i
   vim /etc/sudoers
   ```

   add a new line:

   ```txt
   jacob ALL=(ALL) ALL
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

## Generate SSH key and add to GitHub

Execute the following command:

```sh
ssh-keygen -t rsa
```

Copy the public key to your [GitHub account](https://github.com/settings/keys):

```sh
cat ~/.ssh/id_rsa.pub
```

## Copy SSH key and add to remote server

```sh
cat ~/.ssh/id_rsa.pub
```

Copy the public key to the remote server `~/.ssh/authorized_keys` (create one, if doesn't exist).
If `authorized_keys` needs to be create, make sure its permissions are correct:

```sh
chown -R $USER:$USER ~/.ssh
```

### Issues may occur

- [GitHub Error: Key already in use](https://stackoverflow.com/questions/21160774/github-error-key-already-in-use)

  for short:

  ```sh
  ssh -T -ai ~/.ssh/id_rsa git@github.com
  ```

## Setup Github Cli (Debian/Ubuntu)

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

Visit [Github Token page](https://github.com/settings/tokens) and generate a new token. Copy this token to the terminal when `? Paste your authentication token:` occurs.

## Setup Github Cli (CentOS)

1. Install [DNF](https://opensource.com/article/18/8/guide-yum-dnf):

   ```sh
   sudo yum install epel-release
   sudo yum install dnf
   dnf --version
   ```

1. Using DNF to install `gh`:

   ```sh
   sudo dnf install 'dnf-command(config-manager)'
   sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
   sudo dnf install gh
   ```

1. Authentication:

   ```sh
   gh auth login
   ```
