+++
title="WSL setup"
description="Setup WSL SSH"
date=2024-01-22

[taxonomies]
categories = ["Doc"]
+++

## Enable OpenSSH for Windows

Run PowerShell as an Administrator:

```sh
Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH*'
```

Install server or client:

```sh
# Install the OpenSSH Client
Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0

# Install the OpenSSH Server
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
```

Start and configure OpenSSH server:

```sh
# Start the sshd service
Start-Service sshd

# OPTIONAL but recommended:
Set-Service -Name sshd -StartupType 'Automatic'

# Confirm the Firewall rule is configured. It should be created automatically by setup. Run the following to verify
if (!(Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue | Select-Object Name, Enabled)) {
    Write-Output "Firewall Rule 'OpenSSH-Server-In-TCP' does not exist, creating it..."
    New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
} else {
    Write-Output "Firewall rule 'OpenSSH-Server-In-TCP' has been created and exists."
}
```

## Enable OpenSSH for WSL2

Install openssh-server:

```sh
sudo apt install openssh-server
```

Enable the ssh service:

```sh
sudo systemctl enable --now ssh
```

## Final Step

Proxy jumping:

```sh
ssh -J <windows_host_username>@<ip_of_your_windows_pc> <wsl_username>@localhost
```

## Reference

- [Get started with OpenSSH for Windows](https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh_install_firstuse?tabs=powershell)

- [Remoting into WSL2 externally - the easy way](https://www.carteakey.dev/remoting-into-wsl2-externally-the-easy-way/)
