# Norschel (Xebia) Hyper-V Action (HyperV)

Remote control one or many virtual machine(s) on a (remote) Hyper-V Server (without SCVMM).
This GitHub Actions action supports start and stop a virtual machine plus create, restore and delete Hyper-V snapshots.

## Changelog / What's new?

- v1
  - Ported Azure Pipeline Hyper-V task to GitHub Actions action, based on v8 [VS Marketplace](https://marketplace.visualstudio.com/items?itemName=Orschel.HyperV)
  - Added (PowerShell over) SSH mode (for cross-platform support)
  - Renamed commands for consistency
- v2:  
  - Updated to  @actions/github v6.0.0
  - Node20 support
  - Allow to choose PowerShell Core / Windows PowerShell
  - Moved logging commands into library to allow using core script for GH action and AzD pipeline task

## Usage

<!-- start usage -->
```yaml
uses: norschel/GitHubActions.HyperV@v2
name: Hyper-V - StartVM
with:
  # Hyper-V hostname (FQDN, hostname or IP)
  hostname: localhost
  # Hyper-V virtual machine name
  # vmname support one or more vm names
  # e.g. Name1,Name2,Name3
  vmname: win11test
  # available commands: startvm / stopvm / createcheckpoint / removecheckpoint
  command: startvm
  # only used in checkpoint commands, optional for all other commands
  checkpointname: GitHubTest
  # optional: Connect to HyperV host using an SSH connection, default is false
  sshmode: false
  # SSH hostname (servername, FQDN or IP)
  # only required if sshmode is enabled
  sshhostname: hostname
  # SSH port, default: 21
  # only required if sshmode is enabled
  sshport: 21
  # SSH username
  # only required if sshmode is enabled
  sshusername: username
  # SSH password
  # only required if sshmode is enabled
  sshpassword: password
  # SSH private key, can be used instead of passwort
  # Private key takes priority over password, should be used together with secrets
  # only required if sshmode is enabled
  sshprivatekey: key
  # Optional for all commands, used only with command startv, default: HeartBeatApplicationsHealthy
  # Available values: WaitingTime,  HeartBeatApplicationsHealthy
  startvmstatuscheckType: WaitingTime
  # Optional, only required if used with command startvm and checktype WaitingTime
  startvmwaittimebasedcheckinterval: 30
  # (Very) Optional, configures number of notifications during status checks, default: 20
  hyperv_startvmwaitingnumberofstatusnotifications:
  # (Very) Optional, configues heartbeat timeout, default: 300 sec
  hyperv_startvmapphealthyheartbeattimeout:
  # (Very) Optional, allows to load older Hyper-V commandlet versions (e.g. Win 2012 support)
  hyperv_psmoduleversion: 2.0
  # Optional, use PowerShell Core instead of Windows PowerShell, default: true
  pwshcore: true
  
```
<!-- end usage -->  

## Getting Started

The action is written using TypeScript and PowerShell. PowerShell is responsible for controlling Hyper-V using the Hyper-V module for Windows PowerShell (part of Hyper-V management tools). TypeScript is used for creating the script arguments for the Hyper-V script and executing the script using PowerShell shell.

It's even possible to use SSH for executing the script on remote Windows servers. On Windows it's recommended to use PowerShell without SSH (PowerShell remote mode). All other operating systems should use SSH to control Windows Hyper-V servers. If you like use SSH mode, then you need to install OpenSSH server plus Hyper-V module on a Windows Server.

The core logic script uses internally PowerShell (version 4 or newer recommended) as well as the Hyper-V module for Windows PowerShell.

Prerequisites:

- PowerShell mode
  - GitHub Actions Runner must run on Windows
  - Runner (service) user must be member of "Hyper-V Administrators" group on (remote) Hyper-V server
  - Hyper-V module for Windows PowerShell is installed on GitHub Runner system, for installation instructions see official Microsoft documentation ( [Link](https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2012-R2-and-2012/dn632582(v=ws.11)?redirectedfrom=MSDN#installing-the-hyper-v-management-tools))

- SSH Mode
  - Use this mode if your GitHub Actions Runner is running on non-Windows operating systems!!!
  - GitHub Actions Runner can be installed on every supported operating system (incl. Windows)
  - SSH user must be member of "Hyper-V Administrators" group on (remote) Hyper-V server
  - OpenSSH server (Windows optional features) is installed on Windows, for installation instruction see official Microsoft documentation ([Link](https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh_install_firstuse?tabs=gui#install-openssh-for-windows))
  - Hyper-V module is installed on the same system as OpenSSH server, for installation instructions see official Microsoft documention ( [Link](https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2012-R2-and-2012/dn632582(v=ws.11)?redirectedfrom=MSDN#installing-the-hyper-v-management-tools))
  - OpenSSH server and Hyper-V module can be installed directly on Hyper-V server but it's also possible to use another Windows Server to act as a gateway for many Microsoft Hyper-V servers.

## Build and Test

The action can be built using TypeScript and Visual Studio Code.
The dependencies are managed via NPM.

The action is primarily tested manually because different Hyper-V / host os versions and the appropriate Hyper-V cmdlets are required. Especially in older versions Hyper-V module are not always backward-compatible (Pre - Windows 10).

## Contribute

Contributions to the Hyper-V GitHub Actions action are welcome. Some ways to contribute are to try things out, file issues and make pull-requests.

## The past and the future

This repo and action is based on Azure Pipelines Hyper-V task v8 ([VS Marketplace](https://marketplace.visualstudio.com/items?itemName=Orschel.HyperV)).
In the future we try to use the same back-end script (ps1) for both targets (Azure Pipelines and GitHub Actions.)
