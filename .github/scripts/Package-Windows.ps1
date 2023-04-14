[CmdletBinding()]
param(
    [ValidateSet('x64')]
    [string] $Target = 'x64',
    [switch] $BuildInstaller = $false
)

$ErrorActionPreference = 'Stop'

if ( $DebugPreference -eq 'Continue' ) {
    $VerbosePreference = 'Continue'
    $InformationPreference = 'Continue'
}

if ( $PSVersionTable.PSVersion -lt '7.0.0' ) {
    Write-Warning 'The obs-deps PowerShell build script requires PowerShell Core 7. Install or upgrade your PowerShell version: https://aka.ms/pscore6'
    exit 2
}

function Package {
    trap {
        Pop-Location -Stack BuildTemp -ErrorAction 'SilentlyContinue'
        Write-Error $_
        Log-Group
        exit 2
    }

    $ScriptHome = $PSScriptRoot
    $ProjectRoot = Resolve-Path -Path "$PSScriptRoot/../.."
    $BuildSpecFile = "${ProjectRoot}/buildspec.json"

    $UtilityFunctions = Get-ChildItem -Path $PSScriptRoot/utils.pwsh/*.ps1 -Recurse

    foreach( $Utility in $UtilityFunctions ) {
        Write-Debug "Loading $($Utility.FullName)"
        . $Utility.FullName
    }

    $BuildSpec = Get-Content -Path ${BuildSpecFile} -Raw | ConvertFrom-Json
    $ProductName = $BuildSpec.name
    $ProductVersion = $BuildSpec.version

    $OutputName = "${ProductName}-${ProductVersion}-windows-${Target}"

    Install-BuildDependencies -WingetFile "${ScriptHome}/.Wingetfile"

    if ( $Env:CI -ne $null ) {
        switch ( $Env:GITHUB_EVENT_NAME ) {
            pull_request {
                $BuildConfiguration = 'RelWithDebInfo'
            }
            push {
                if ( $Env:GITHUB_REF_NAME -match '[0-9]+.[0-9]+.[0-9]+(-(rc|beta).+)?' ) {
                    $BuildConfiguration = 'Release'
                } else {
                    $BuildConfiguration = 'RelWithDebInfo'
                }
            }
        }
    } else {
        $BuildConfiguration = 'Release'
    }

    $RemoveArgs = @{
        ErrorAction = 'SilentlyContinue'
        Path = @(
            "${ProjectRoot}/release/${ProductName}-*-windows-*.zip"
            "${ProjectRoot}/release/${ProductName}-*-windows-*.exe"
        )
    }

    Remove-Item @RemoveArgs

    if ( ( $BuildInstaller ) ) {
        Log-Group "Packaging ${ProductName}..."
        $IsccFile = "${ProjectRoot}/build_${Target}/installer-Windows.generated.iss"

        if ( ! ( Test-Path -Path $IsccFile ) ) {
            throw 'InnoSetup install script not found. Run the build script or the CMake build and install procedures first.'
        }

        Log-Information 'Creating InnoSetup installer...'
        Push-Location -Stack BuildTemp
        Ensure-Location -Path "${ProjectRoot}/release"
        Copy-Item -Path ${BuildConfiguration} -Destination Package -Recurse
        Invoke-External iscc ${IsccFile} /O"${ProjectRoot}/release" /F"${OutputName}-Installer"
        Remove-Item -Path Package -Recurse
        Pop-Location -Stack BuildTemp
    } else {
        Log-Group "Archiving ${ProductName}..."
        $CompressArgs = @{
            Path = (Get-ChildItem -Path "${ProjectRoot}/release/${BuildConfiguration}" -Exclude "${OutputName}*.*")
            CompressionLevel = 'Optimal'
            DestinationPath = "${ProjectRoot}/release/${OutputName}.zip"
            Verbose = ($Env:CI -ne $null)
        }

        Compress-Archive -Force @CompressArgs
    }
    Log-Group
}

Package
