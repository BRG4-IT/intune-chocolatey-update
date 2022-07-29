# Updating Software with intune and chocolatey

[Chocolatey](https://chocolatey.org/) is a [package manager](https://en.wikipedia.org/wiki/Package_manager) for [Windows](https://en.wikipedia.org/wiki/Microsoft_Windows). Deploying Software with [intune](https://de.wikipedia.org/wiki/Microsoft_Intune) using chocolatey makes life easier.

__Important: Using the scripts in this project works only, if programms have been installed with Chocolatey on the local computer.__ Software can be deployed via intune using chocolatey by using the scripts found in [intune-chocolatey](https://github.com/BRG4-IT/intune-chocolatey)


## How it works

Updates on clients are initiated by "misunsing" the intune software depolyment mechanism. 
So far detect scripts cannot have parameters. 
Thus every update "installation" needs a seperate script to test for success. 
To get your custom detection script download the script template [./choco-update-package/choco-update-package-detect.ps1](./choco-update-package/choco-update-package-detect.ps1?raw=true) and enter the same Parameters as used in the Ìnstall` line to the function at the end of the script.

## Example usages

Please follow instructions found in:

- [./demo-update-VLC-Daily/README.md](./demo-update-VLC-Daily/README.md)
- [./demo-update-7zip,audacity-Monthly/README.md](./demo-update-7zip,audacity-Monthly/README.md)
- [./demo-update-ALL-Yearly/README.md](./demo-update-ALL-Yearly/README.md)


## Convert scripts to .intunewin

You will find the necessary `.intunewin` file precompiled in [./choco-update-package/choco-update-package_v0.8.intunewin](./choco-update-package/choco-update-package_v0.8.intunewin?raw=true). If you like you can compile the files on your own:

1. Clone/download this repository
2. Download the [IntuneWinAppUtil](https://github.com/Microsoft/Microsoft-Win32-Content-Prep-Tool) Programm
3. Move `IntuneWinAppUtil.exe` to the root of this repository
4. Open a command prompt or a Powershell console
5. Navigate to the root of this repository
6. Execute the following commands:

```
.\IntuneWinAppUtil.exe -c .\choco-update-package -s choco-update-package.ps1 -o .\choco-update-package
```
