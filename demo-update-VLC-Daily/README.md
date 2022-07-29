## Update VLC Every Day (intune/chocolatey)

### App-Typ:

__Windows-App (Win32)__

App-Paketdatei auswählen:

[../choco-update-package/choco-update-package_v0.8.intunewin](../choco-install-package/choco-update-package_v0.8.intunewin?raw=true)


### Name:

```
Update VLC Daily
```

### Description (Beschreibung):

```
Update VLC every Day
```

### Publisher (Herausgeber)

```
BRG4
```


### Informations-URL:

```
https://github.com/BRG4-IT/intune-chocolatey-update
```


### Install:
```
powershell.exe -executionpolicy bypass -file ".\choco-update-package.ps1" -Names "VLC" -StartingWith "2022.02.21 13:00:00" -RepeatEvery "Day" -Log
```

Note: If not spedified by the `-LogPath` parameter, update process is logged to a file `%ALLUSERSPROFILE%\Microsoft\IntuneManagementExtension\logs\choco-update\choco-update-package_7zip-audacity_Month-yyyy-MM-dd-HHmmss.log`. If logging is not wanted, simply omit the `-Log` switch.

### Uninstall:
```
powershell.exe -executionpolicy bypass -file ".\choco-update-package.ps1" -Names "VLC" -StartingWith "2022.02.21 13:00:00" -RepeatEvery "Day" -Log
```

Note: The execution of this line has does NOT revert the update! This is a mandatory field, so we use the same line as in 'Install'.




### Detection rules (Erkennungsregeln):

Rule format (Regelformat): __Use a custom detection script (Benutzerdefiniertes Skript für die Erkennung verwenden)__

Script file (Skriptdatei): [choco-update-package-detect-VLC-Daily.ps1](./choco-update-package-detect-VLC-Daily.ps1?raw=true)

Run script as 32-bit process on 64-bit clients: __No__

Enforce script signature check: __No__

### Dependencies (Abhängigkeiten):

chocolatey

Note: In order to work the [Chocolatey package manager](https://chocolatey.org/) has to be installed on the local system. If you are using [intune to deploy chocolatey](https://github.com/BRG4-IT/intune-chocolatey/tree/main/choco-install) on computers, choose this dependency option.
