
<#
    .NAME
        AndroidPlatformToolsUpdater.ps1


    .SYNOPSIS
        Installs and updates Android Platform Tools (ADB, Fastboot ++) and adds install path to Windows Environment Variables.


    .DESCRIPTION
        Installs and updates Android Platform Tools (ADB, Fastboot ++) and adds install path to Windows Environment Variables.

        User Context
            * Installs to "%localappdata%\Android Platform Tools"
            * Will make Android Platform Tools available only to the user logged in when running this script
        
        System Context
            * Installs to "%ProgramFiles(x86)%\Android Platform Tools"
            * Will make Android Platform Tools available to all users on the machine


  
    .EXAMPLE
        # Run from PowerShell ISE, system context
        & $psISE.'CurrentFile'.'FullPath'


    .EXAMPLE
        # Run from PowerShell ISE, user context
        & $psISE.'CurrentFile'.'FullPath' -SystemWide $false


    .NOTES
        Author:   Olav Rønnestad Birkeland
        Created:  190310
        Modified: 210910
#>




# Input parameters
[OutputType($null)]
Param (

)




# PowerShell preferences
## Output Streams
$DebugPreference       = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'
$VerbosePreference     = 'SilentlyContinue'
$WarningPreference     = 'Continue'

## Behaviour
$ConfirmPreference     = 'None'
$ProgressPreference    = 'SilentlyContinue'




#region    Functions   
#region    Get-AndroidPlatformToolsInstalledVersion
function Get-AndroidPlatformToolsInstalledVersion {
    <#
        .SYNOPSIS
            Gets Android Platform Tools version already installed in given path on the system.
    #>
            
            
    # Input parameters            
    [CmdletBinding()]
    [OutputType([System.Version])]
    Param(
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string] $PathDirAndroidPlatformTools = 'C:\\FFA\\platform-tools'
    )
            
    # Begin
    Begin {}


    # Process
    Process {
        # Assets
        $PathFileFastboot = [string]('{0}\fastboot.exe' -f ($PathDirAndroidPlatformTools))

        # Version of existing install, Version 0.0.0.0 if not found
        $VersionFileFastbootExisting = [System.Version]$(
            if ([System.IO.File]::Exists($PathFileFastboot)) {
                Try{[System.Version]$([string](cmd /c ('"{0}" --version' -f ($PathFileFastboot))).Split(' ')[2].Replace('-','.'))}Catch{'0.0.0.0'}
            }
            else {
                '0.0.0.0'
            }
        )
    }
            

    # End
    End {
        return $VersionFileFastbootExisting
    }
}
#endregion Get-AndroidPlatformToolsInstalledVersion



#region    Install-AndroidPlatformToolsLatest
function Install-AndroidPlatformToolsLatest {
    <#
        .SYNOPSIS
            Installs Android Platform Tools Latest Version to given Path.
                       
        .PARAMETER PathDirAndroidPlatformTools
            Path to where Android Platform Tools will be installed.
            Optional String [string].
            Default value: "%ProgramFiles(x86)%\Android Platform Tools"

        .PARAMETER VersionFileFastbootInstalled
            Currently installed version of Android Platform Tools.
            Optional Variable, Version [System.Version].
            Default value: Function "Get-AndroidPlatformToolsInstalledVersion".

        .PARAMETER CleanUpWhenDone
            Whether to clean up downloaded and extracted files when done.
            Optional variable, boolean.
            Default value: $True.
    #>
            
            
    # Input parameters
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    Param (
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string] $PathDirAndroidPlatformTools = 'c:\\FFA\\platform-tools' -f $(
         
        ),

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [System.Version] $VersionFileFastbootInstalled = [System.Version](Get-AndroidPlatformToolsInstalledVersion),

        [Parameter(Mandatory = $false)]
        [bool] $CleanUpWhenDone = $true
    )


    # Begin
    Begin {
        # Assets - Function help variables
        $CurrentUserIsAdmin = [bool](
            ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
                [Security.Principal.WindowsBuiltInRole]::Administrator
            )
        )
        $Success = [bool] $false
                
        # Assets - Downlaod link
        $UrlFileAndroidPlatformTools          = [string] 'https://dl.google.com/android/repository/platform-tools-latest-windows.zip'
                
        # Assets - Temp directory
        $PathDirTemp                          = [string] $env:TEMP
        $PathDirTempAndroidPlatformTools      = [string] '{0}\platform-tools' -f $PathDirTemp
        $PathFileTempFastboot                 = [string] '{0}\fastboot.exe' -f $PathDirTempAndroidPlatformTools
        $PathFileDownloadAndroidPlatformTools = [string] '{0}\{1}' -f $PathDirTemp,$UrlFileAndroidPlatformTools.Split('/')[-1]
    }
    
            
    # Process
    Process {   
        # Remove existing files
        $([string[]]($PathDirTempAndroidPlatformTools,$PathFileDownloadAndroidPlatformTools)).ForEach{
            if (Test-Path -Path $_) {
                $null = Remove-Item -Path $_ -Recurse -Force -ErrorAction 'Stop'
            }
        }


        # Download                
        $Success = [bool]$(Try{[System.Net.WebClient]::new().DownloadFile($UrlFileAndroidPlatformTools,$PathFileDownloadAndroidPlatformTools);$?}Catch{$false})
        if (-not($Success -and [System.IO.File]::Exists($PathFileDownloadAndroidPlatformTools))) {
            Throw ('ERROR: Failed to download "{0}".' -f ($UrlFileAndroidPlatformTools))
        }
    
      
        # Extract
        ## Write information
                
        ## See if 7-Zip is present
        $7Zip = [string]$(
            $([string[]]($env:ProgramW6432,${env:CommonProgramFiles(x86)})).Where{
                [System.IO.Directory]::Exists($_)
            }.ForEach{
                '{0}\7-Zip\7z.exe' -f $_
            }.Where{
                [System.IO.File]::Exists($_)
            } | Select-Object -First 1
        )

        ## Use 7-Zip if present, fall back to built in method                
        if (-not[string]::IsNullOrEmpty($7Zip)) {
            $7ZipArgs = [string] 'x "{0}" -aoa -o"{1}" -y' -f $PathFileDownloadAndroidPlatformTools, $PathDirTemp
            $null = Start-Process -WindowStyle 'Hidden' -Wait -FilePath $7Zip -ArgumentList $7ZipArgs                    
            $Success = [bool]($? -and [System.IO.Directory]::Exists($PathDirTempAndroidPlatformTools))
        }
        if ([string]::IsNullOrEmpty($7Zip) -or -not $Success) {
            Add-Type -AssemblyName 'System.IO.Compression.FileSystem'
            $Success = [bool]$(
                Try {
                    [System.IO.Compression.ZipFile]::ExtractToDirectory($PathFileDownloadAndroidPlatformTools,$PathDirTemp)
                    $?
                }
                Catch {
                    $false
                }
            )
        }

        ## Check success
        if (-not($Success -and [System.IO.File]::Exists($PathFileTempFastboot))) {
            Throw ('ERROR: Failed to extract "{0}".' -f ($PathFileDownloadAndroidPlatformTools))
        }
    

        # Version of download Android Platform Tools
        $VersionFileFastbootDownloaded = [System.Version]$(
            if (Test-Path -Path $PathFileTempFastboot) {
                Try{[System.Version]$([string](cmd /c ('"{0}" --version' -f ($PathFileTempFastboot))).Split(' ')[2].Replace('-','.'))}Catch{'0.0.0.0'}
            }
            else {
                '0.0.0.0'
            }
        )
        if ($VersionFileFastbootDownloaded -eq [System.Version]('0.0.0.0')) {
            Throw ('ERROR: Failed to get version info from "{0}".' -f ($PathFileTempFastboot))
        }


        # Install Downloaded version if newer that Installed Version
        if ($VersionFileFastbootDownloaded -gt $VersionFileFastbootInstalled) {            
 

            # Kill ADB and Fastboot if running
            $([string[]]('adb','fastboot')).ForEach{
                $null = Get-Process -Name $_ -ErrorAction 'SilentlyContinue' | Stop-Process -ErrorAction 'Stop'
            }
            
            # Remove Existing Files if they Exist
            if ([System.IO.Directory]::Exists($PathDirAndroidPlatformTools)) {
                $null = Remove-Item -Path $PathDirAndroidPlatformTools -Recurse -Force -ErrorAction 'Stop'
                if ((-not($?)) -or [System.IO.Directory]::Exists($PathDirAndroidPlatformTools)) {
                    Throw ('ERROR: Failed to remove existing files in "{0}".' -f $PathAndroidPlatformTools)
                }
            }

            # Install Downloaded Files
            Move-Item -Path $PathDirTempAndroidPlatformTools -Destination $PathDirAndroidPlatformTools -Force -Include '*'
            
            # Capture Operation Success
            $Success = [bool] $?
        }
        else {
            # Write information
        }
    }


    # End
    End {
        # Clean up
        if ($CleanUpWhenDone) {
            $([string[]]($PathDirTempAndroidPlatformTools,$PathFileDownloadAndroidPlatformTools)).ForEach{
                if (Test-Path -Path $_) {
                    $null = Remove-Item -Path $_ -Recurse -Force -ErrorAction 'Stop'
                }
            }
        }


        # Return success status
        return $Success
    }
}
#endregion Install-AndroidPlatformToolsLatest



#region    Add-AndroidPlatformToolsToEnvironmentVariables
function Add-AndroidPlatformToolsToEnvironmentVariables {
    <#
        .SYNOPSIS
            Adds path to Android Platform Tools to Windows Environment Variables for Current User ONLY.

        .PARAMETER PathDirAndroidPlatformTools
            Path to where Android Platform Tools will be installed.
            Optional String [string].
            Default Value: "%ProgramFiles(x86)%\Android Platform Tools".

        .PARAMETER SystemWide
            Add to Environment Variables for Current User (HKCU) only, or System Wide (HKLM).
            Optional Boolean [bool].
            Default Value: $false.
    #>
            
            
    # Input parameters
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    Param(
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({[System.IO.Directory]::Exists($_)})]
        [string] $PathDirAndroidPlatformTools = 'C:\\FFA\\platform-tools' -f $(
           {
                $env:LOCALAPPDATA
           }
        )

    )
    

    # Begin
    Begin {
        $Success = [bool] $true
        $Target  = [string] $('User')
    }

            
    # Process
    Process {
        # Get existing PATH Environment Variable
        $PathVariableExisting = [string[]]([System.Environment]::GetEnvironmentVariables($Target).'Path'.Split(';') | Sort-Object)
        $PathVariableNew      = [Management.Automation.PSSerializer]::DeSerialize([Management.Automation.PSSerializer]::Serialize($PathVariableExisting))

        # Add Android Platform Tools if not already present
        if ($PathVariableNew -notcontains $PathDirAndroidPlatformTools) {
            $PathVariableNew += $PathDirAndroidPlatformTools
        }

        # Clean up
        ## Remove ending '\' and return unique entries only
        $PathVariableNew = [string[]](
            $PathVariableNew.ForEach{
                if ($_[-1] -eq '\') {
                    $_.SubString(0,$_.'Length'-1)
                }
                else {
                    $_
                }
            } | Sort-Object -Unique
        )

        # Change PATH Environment Variable for Current User
        if (([string[]]$(Compare-Object -ReferenceObject $PathVariableNew -DifferenceObject $PathVariableExisting -PassThru)).'Count' -ge 1) {
            # Set new environmental variables
            [System.Environment]::SetEnvironmentVariable('Path',[string]$($PathVariableNew -join ';'),$Target)
            $Success = [bool] $?
        }
        else {
            $Success = [bool] $true
        }
    }


    # End
    End {
        Return $Success
    }
}
#endregion Add-AndroidPlatformToolsToEnvironmentVariables


#region    Get-AdbVersionFromWebpage
function Get-AndroidPlatformToolsFromWebpage {
    [OutputType([System.Version])]
    Param()
    Try {
        [System.Net.WebClient]::new().DownloadString('https://developer.android.com/studio/releases/platform-tools').Split(
            [System.Environment]::NewLine,
            [System.StringSplitOptions]::RemoveEmptyEntries
        ).ForEach{
            $_.Trim() -replace '\s{2,}', ' '
        }.Where{
            $_ -like '<h4 id=*'
        }[0].Split('>')[1].Split(' ')[0]
    }
    Catch {
        '0.0.0.0'
    }
}
#endregion Get-AdbVersionFromWebpage
#endregion Functions





#region    Main
    # Help variables
    ## Current user and context
    $CurrentUserName = [string] [System.Security.Principal.WindowsIdentity]::GetCurrent().'Name'
    $CurrentUserSID  = [string] [System.Security.Principal.WindowsIdentity]::GetCurrent().'User'.'Value'
    $IsAdmin  = [bool](([System.Security.Principal.WindowsPrincipal]([System.Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator))
    $IsSystem = [bool]($CurrentUserSID -eq 'S-1-5-18')
    
    ## Output path for Android Platform Tools
    $PathDirAndroidPlatformTools = [string]('C:\\FFA\\platform-tools')
    

    # Write info     

    # Failproof
    ## Check if running as Administrator if $SystemWide
    
        


    $VersionInstalled = [System.Version](Get-AndroidPlatformToolsInstalledVersion -PathDirAndroidPlatformTools $PathDirAndroidPlatformTools)    

    
    ## Available version

    $VersionAvailable = [System.Version](Get-AndroidPlatformToolsFromWebpage)



    # Install platform-tools

    if (
        $VersionAvailable -gt $VersionInstalled        
    ) {
        $Success = [bool](
            Install-AndroidPlatformToolsLatest -PathDirAndroidPlatformTools $PathDirAndroidPlatformTools -VersionFileFastbootInstalled $VersionInstalled
        )
   }
    $Success = [bool](Add-AndroidPlatformToolsToEnvironmentVariables -PathDirAndroidPlatformTools $PathDirAndroidPlatformTools)

#endregion Main
