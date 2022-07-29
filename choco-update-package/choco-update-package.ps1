<#
    script for updating chocolatey packages with intune
    
    Note: Please detect "installation" with modified version script choco-update-package-detect.ps1
    Note: updates will be repeated until successful.

    examples:
    
    # update choco packages "audacity" and "VLC" on every monday (since 21.02.2022 was a monday)
    choco-update-package -Names "audacity","VLC" -StartingWith "2022.02.21 13:00:00" -RepeatEvery "Week"

    # update choco packages "audacity" and "VLC" on the 21 day of every month
    choco-update-package -Names "audacity","VLC" -StartingWith "2022.02.21 13:00:00" -RepeatEvery "Month"

    # update choco packages  "audacity" and "VLC" every year on the 21th of februrary
    choco-update-package -Names "audacity","VLC" -StartingWith "2022.02.21 13:00:00" -RepeatEvery "Year"

    # update all installed choco packages every year on the 21th of februrary
    # Note: you have to provide the -All switch in order to update all packages, omitting the -Names switch is not sufficent
    choco-update-package -All -StartingWith "2022.02.21 13:00:00" -RepeatEvery "Year"

    # update choco package "audacity" every year on the 21th of februrary, logging successful runs to directory C:\mylogs
    choco-update-package -Names "audacity" -StartingWith "2022.02.21 13:00:00" -RepeatEvery "Year" -LogPath "C:\mylogs"

    # same as above but log to directory "$($env:ALLUSERSPROFILE)\Microsoft\IntuneManagementExtension\Logs\choco-update"
    choco-update-package -Names "audacity" -StartingWith "2022.02.21 13:00:00" -RepeatEvery "Year" -LogPath "choco-update"

#>

param (
    [Parameter(Mandatory=$false)] # list of of the chocolatey package names to update (see https://community.chocolatey.org/packages)
    [string[]]$Names = '',

    [Parameter(Mandatory=$true)] # additional parameters passed to the choco install command
    [DateTime]$StartingWith = $null,
    
    [Parameter(Mandatory=$true)] # update time intervall
    [ValidateSet(
        "Day",
        "Week",  # Repeat every Week on the same weekday as in -StartingWith (e.g. if starting date is a monday, updates will be run every monday)
        "Month", # Repeat every Month on the same day of the month as in -StartingWith (e.g. if starting date is the 21.02, updates will be run on 21.03, 21,04,...)
        "Year"   # Repeat every Year on the same day as in -StartingWith (e.g. if starting date is the the 21.02.2022, updates will be run on 21.02.2023, 21.02.2024,...)
    )]
    [string]$RepeatEvery,
    
    [Parameter(Mandatory=$false)] # if set, all packages are updated (in this case the -Names parameter will be ignored)
    [switch]$All = $false,

    [Parameter(Mandatory=$false)] # if set, logs script parameters and script output to file
    [switch]$Log = $false,
    
    [Parameter(Mandatory=$false)] # Path to folder for logfiles
    [string]$LogPath = "choco-update"
)




### functions Get-Shortcut, Set-Shortcut by Tim Lewis taken from 
### https://stackoverflow.com/questions/484560/editing-shortcut-lnk-properties-with-powershell#answer-21967566

function Get-Shortcut {
  param(
    $path = $null
  )

  $obj = New-Object -ComObject WScript.Shell

  if ($path -eq $null) {
    $pathUser = [System.Environment]::GetFolderPath('StartMenu')
    $pathCommon = $obj.SpecialFolders.Item('AllUsersStartMenu')
    $path = dir $pathUser, $pathCommon -Filter *.lnk -Recurse 
  }
  if ($path -is [string]) {
    $path = dir $path -Filter *.lnk
  }
  $path | ForEach-Object { 
    if ($_ -is [string]) {
      $_ = dir $_ -Filter *.lnk
    }
    if ($_) {
      $link = $obj.CreateShortcut($_.FullName)

      $info = @{}
      $info.Hotkey = $link.Hotkey
      $info.TargetPath = $link.TargetPath
      $info.LinkPath = $link.FullName
      $info.Arguments = $link.Arguments
      $info.Target = try {Split-Path $info.TargetPath -Leaf } catch { 'n/a'}
      $info.Link = try { Split-Path $info.LinkPath -Leaf } catch { 'n/a'}
      $info.WindowStyle = $link.WindowStyle
      $info.IconLocation = $link.IconLocation

      New-Object PSObject -Property $info
    }
  }
}

function Set-Shortcut {
  param(
  [Parameter(ValueFromPipelineByPropertyName=$true)]
  $LinkPath,
  $Hotkey,
  $IconLocation,
  $Arguments,
  $TargetPath
  )
  begin {
    $shell = New-Object -ComObject WScript.Shell
  }

  process {
    $link = $shell.CreateShortcut($LinkPath)

    $PSCmdlet.MyInvocation.BoundParameters.GetEnumerator() |
      Where-Object { $_.key -ne 'LinkPath' } |
      ForEach-Object { $link.$($_.key) = $_.value }
    $link.Save()
  }
}




### passing an array does not work like expected. Temporary workaround

if ($Names.length -eq 1 -and $Names[0] -match ",") {
    Write-Host "expanding names to array"
    $Names = $Names -split ","
}


$successfileExtension = "success"
$successSubDir = "success"
$successPath = ""
$lastUpdateDateTime = $null


$packageListString = "all"
if (-Not $All) {
    If ([string]::IsNullOrEmpty($Names)) {            
        Write-Host "missing -All or -Names Parameter. Aborting Script."
        exit 1
    }
    $packageListString = $Names -join "-"
}

#########################################
### directories for log and success files
#########################################

$MSIntuneDefaultLogPath = "$($env:ALLUSERSPROFILE)\Microsoft\IntuneManagementExtension\Logs"
If ([string]::IsNullOrEmpty($LogPath)) {
    $LogPath = $MSIntuneDefaultLogPath
}
elseIf (-not ([System.IO.Path]::IsPathRooted($LogPath))) {
    $LogPath = (Join-Path $MSIntuneDefaultLogPath $LogPath)
}
If (-not (Test-Path -Path $LogPath)) {
    New-Item -ItemType Directory -Force -Path $LogPath | Out-Null
}
If (-not (Test-Path -Path $LogPath)) {  # fallback
    Write-Host "$LogPath could not be created. Writing all log files to HOMEDRIVE."
    $LogPath = "$($env:HOMEDRIVE)\"
}
else {
    Write-Host "logging to $LogPath"
}
$successPath = (Join-Path $LogPath $successSubDir)
If (-not (Test-Path -Path $successPath)) {
    New-Item -ItemType Directory -Force -Path $successPath | Out-Null
}
Write-Host "success files will be written to $successPath"

###########################
### start log file
###########################

$logfileName = "$LogPath\choco-update-package_$($packageListString)_$($RepeatEvery)_$(get-date -f yyyy-MM-dd-HHmmss).log"

if ($Log) {
    $ErrorActionPreference="SilentlyContinue"
    Stop-Transcript | out-null
    $ErrorActionPreference = "Continue"
    Start-Transcript -path $logfileName -append
    if ([Environment]::Is64BitProcess) {
        Write-Host "Script running as 64-bit process."
    }
    else {
        Write-Host "Script running as 32-bit process."
    }
    Write-Host "Script parameters:"
    foreach ($p in $PsBoundParameters.GetEnumerator()) {
        Write-Host "$($p.Key) = $($p.Value)"
    }
    Write-Host "`n"
}

###########################
### build success file name
###########################

$now = Get-Date
Write-Host "now: $(Get-Date $now -Format D)"
switch ( $RepeatEvery ) {
    Day {
        Write-Host "daily update cycle"
        $lastUpdateDateTime = Get-Date  -Year $now.Year `
                                        -Month $now.Month `
                                        -Day $now.Day `
                                        -Hour $StartingWith.Hour `
                                        -Minute $StartingWith.Minute `
                                        -Second $StartingWith.Second
        Write-Host "calculated last update time: $(Get-Date $lastUpdateDateTime -Format D)"
        if ($lastUpdateDateTime -gt $now) {
            $lastUpdateDateTime = $lastUpdateDateTime.AddDays(-1)
            Write-Host "corrected last update time: $(Get-Date $lastUpdateDateTime -Format D)"
        }
    }
    Week {
        Write-Host "weekly update cycle"
        $lastUpdateDateTime = Get-Date  -Year $now.Year `
                                        -Month $now.Month `
                                        -Day $now.Day `
                                        -Hour $StartingWith.Hour `
                                        -Minute $StartingWith.Minute `
                                        -Second $StartingWith.Second
        Write-Host "calculated last update time: $(Get-Date $lastUpdateDateTime -Format D)"
        $lastUpdateDateTime = $lastUpdateDateTime.AddDays($StartingWith.DayOfWeek.value__-$lastUpdateDateTime.DayOfWeek.value__)
        if ($lastUpdateDateTime -gt $now) {
            $lastUpdateDateTime = $lastUpdateDateTime.AddDays(-7)
            Write-Host "corrected last update time: $(Get-Date $lastUpdateDateTime -Format D)"
        }
    }
    Month {
        Write-Host "mounthly update cycle"
        $lastUpdateDateTime = Get-Date  -Year $now.Year `
                                        -Month $now.Month `
                                        -Day $StartingWith.Day `
                                        -Hour $StartingWith.Hour `
                                        -Minute $StartingWith.Minute `
                                        -Second $StartingWith.Second
        Write-Host "calculated last update time: $(Get-Date $lastUpdateDateTime -Format D)"
        if ($lastUpdateDateTime -gt $now) {
            $lastUpdateDateTime = $lastUpdateDateTime.AddMonths(-1)
            Write-Host "corrected last update time: $(Get-Date $lastUpdateDateTime -Format D)"
        }
    }
    Year {
        Write-Host "yearly update cycle"
        $lastUpdateDateTime = Get-Date  -Year $now.Year `
                                        -Month $StartingWith.Month `
                                        -Day $StartingWith.Day `
                                        -Hour $StartingWith.Hour `
                                        -Minute $StartingWith.Minute `
                                        -Second $StartingWith.Second
        Write-Host "calculated last update time: $(Get-Date $lastUpdateDateTime -Format D)"
        if ($lastUpdateDateTime -gt $now) {
            $lastUpdateDateTime = $lastUpdateDateTime.AddYears(-1)
            Write-Host "corrected last update time: $(Get-Date $lastUpdateDateTime -Format D)"
        }
    }
    default {
        Write-Host "Error unknown Time Interval: $RepeatEvery"
        exit 1
    }
}

# Write-Host "Last successful run should have been on $(Get-Date $lastUpdateDateTime -Format D)."

$d = ([string]$lastUpdateDateTime.Day).PadLeft(2,'0')
$m = ([string]$lastUpdateDateTime.Month).PadLeft(2,'0')
$y = $lastUpdateDateTime.Year
$baseFileName = "choco-update-package_$y-$m-$($d)`_($($RepeatEvery.ToLower())ly)_$packageListString"
$successFileName = "$baseFileName.$successfileExtension"





##################
### do the updates
##################

if (Test-Path "$successPath\$successFileName") {
    Write-Host "Nothing to do. File $successFileName found => Last scheduled update has been successful."
}
else {
    Write-Host "Last successful run should have been on $($lastUpdateDateTime). File $successFileName not found => begin update."
    $ThereWereErrors = $false
    if ($All) {
        Write-Host "updating all choco packages on client"
        choco upgrade all -y
        if ($LASTEXITCODE -ne 0) {
            $ThereWereErrors = $true
        }
    }
    else {
        $Names | foreach {
            $packageName = $_
            Write-Host "updating choco package $packageName on client"
            choco upgrade "$packageName" -y
            if ($LASTEXITCODE -ne 0) {
                $ThereWereErrors = $true
            }
        }
    }
    if (-not $ThereWereErrors) {
        Write-Host "successful run. writing file '$successPath\$successFileName'..."
        Get-Date | Out-file "$successPath\$successFileName"
    }


    #####################################################
    ### Find broken Desktop Shortcuts and try to fix them
    #####################################################

    Write-Host "`nTry to fix now invalid desktop icons"

    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if ($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host "SYSTEM context (all users Desktop)"
        $DesktopPath = "$([Environment]::GetFolderPath('CommonDesktopDirectory'))"
    }
    else {
        Write-Host "USER context (current user Desktop)"
        $DesktopPath = "$([Environment]::GetFolderPath("Desktop"))"
    }
    $DesktopLNKs = Get-ChildItem -path "$DesktopPath\*" -Include *.lnk | Select Name,FullName
    $DesktopLNKs | foreach {
        $lnkPath = $_.FullName
        $lnkFilename = (Get-Item $lnkPath).Basename
        Write-Host "=== Found Shortcut named '$lnkFilename' ($lnkPath)"
        $sObj = Get-Shortcut $lnkPath
        if (-not $sObj) {
            Write-Host "Could not open Shortcut ($lnkPath)"
        }
        else {
            $target = $sObj.TargetPath
            If ([string]::IsNullOrEmpty($target)) {
                Write-Host "TargetPath empty; skipping Shortcut."
            }
            else {
                Write-Host "Checkin target path ($target)"
                if (-Not $target.EndsWith('.exe')) {
                    Write-Host "Ignoring Shortcut (not pointing to an executable file)"
                }
                else {
                    if (Test-Path($target)) {
                        Write-Host "Skipping Shortcut (target points to valid file)."
                    }
                    else {
                        Write-Host "Found broken program Shortcut. Trying to find matching .exe file..."
                        $targetFilename = Split-Path $target -leaf
                        $targetFilePattern = $targetFilename -replace "\d+","*" # replace all numbers in executable filename with wildcards
                        $latestInstanceOfFile = Get-ChildItem -path "${env:ProgramW6432}\*","${env:ProgramFiles(x86)}\*" -recurse -Include "$targetFilePattern" -ErrorAction Ignore | where { ! $_.PSIsContainer } | Sort CreationTime -Descending | select * -First 1
                        if (!$latestInstanceOfFile) {
                            Write-Host "No matching executable (.exe) file found in program files folders..."
                            Write-Host "Removing invalid Shortcut ($lnkFilename.lnk)" -ForegroundColor DarkYellow
                            Remove-Item -Path $lnkPath -Force
                        }
                        else {
                            $prgExePath = $latestInstanceOfFile.FullName
                            $prgVersion = $latestInstanceOfFile.VersionInfo.ProductVersion
                            Write-Host "Matching file found ($prgExePath, Version: $prgVersion)..."

                            # Test if Shortcut name contains version number

                            $newName = $lnkFilename
                            $prgVersion = $prgVersion -replace ",","."
                            if ($lnkFilename -match " [0-9.]+$") {
                                Write-Host "Version number in Shortcut name detected."
                                $oldVersionNumber = ($lnkFilename | select-string -pattern " [0-9.]+$").Matches[0].Value.Trim()
                                $depth = $oldVersionNumber.Split(".").Length
                                $newVersionNumber = $prgVersion.Split(".")[0..($depth-1)] -join(".")
                                $newName = $lnkFilename -replace $oldVersionNumber,$newVersionNumber
                            }
                            Write-Host "Trying to fix/create new shortcut ($newName.lnk)"
                            Set-Shortcut -LinkPath "$DesktopPath\$newName.lnk" -Hotkey $sObj.Hotkey -IconLocation $sObj.IconLocation -Arguments $sObj.Arguments -TargetPath $prgExePath
                            if ($lnkFilename -ne $newName) {
                                Write-Host "Removing obsolete Shortcut ($lnkFilename.lnk)" -ForegroundColor DarkYellow
                                Remove-Item -Path $lnkPath -Force
                            }
                        }
                    }
                }
            }
        }
    }
}


if ($Log) {
    Stop-Transcript
}