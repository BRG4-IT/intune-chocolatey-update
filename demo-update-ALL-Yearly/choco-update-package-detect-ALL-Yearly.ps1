<#
    generic script for detecting success of choco-update-package "installations" with intune
    
    IMPORTANT: THIS SCRIPT IS JUST A TEMPLATE! IN ORDER TO BE USEFULL YOU HAVE TO ADD
               PARAMETERS TO THE THE LAST LINE OF THIS SCRIPT!

#>


function choco-update-package-detect {
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
    If (-not (Test-Path -Path $LogPath)) {  # fallback
        Write-Host "$LogPath could not be found. looking in HOMEDRIVE."
        $LogPath = "$($env:HOMEDRIVE)\"
    }
    $successPath = (Join-Path $LogPath $successSubDir)
    If (-not (Test-Path -Path $successPath)) {
        Write-Host "$successPath does not exist. Maybe update script has not been run once. Detect failed."
        exit 1
    }
    Write-Host "$successPath found"
    
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
    
    $successFilePath = "$successPath\$successFileName"

    if (Test-Path $successFilePath) {
        Write-Host "Nothing to do. File $successFilePath found. Last scheduled update was successful."
        exit 0
    }
    else {
        Write-Host "File $successFilePath not found. Update is overdue!"
        exit 1
    }

}



<#
 At the moment there is no way to pass parameters to an intune detect script. But with this workaround 
 you can use at least the same parameter list as with install/uninstall commands, e.g. if your install command reads
 
   powershell.exe -executionpolicy bypass -file ".\choco-update-package.ps1" -Name "audacity" -StartingWith "2022.02.21 13:00:00" -RepeatEvery "Week"
                                                                             ========================================================================
 use
 
   choco-update-package-detect -Name "audacity" -StartingWith "2022.02.21 13:00:00" -RepeatEvery "Week"
                               ========================================================================
 in the function call below:
#>

choco-update-package-detect -All -StartingWith "2021.07.15 13:00:00" -RepeatEvery "Year"