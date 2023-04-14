[CmdletBinding()]
param(
    [ValidateSet('x64')]
    [string] $Target = 'x64',
    [switch] $SkipAll,
    [switch] $SkipBuild,
    [switch] $SkipDeps
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

function Build {
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

    foreach($Utility in $UtilityFunctions) {
        Write-Debug "Loading $($Utility.FullName)"
        . $Utility.FullName
    }

    $BuildSpec = Get-Content -Path ${BuildSpecFile} -Raw | ConvertFrom-Json
    $ProductName = $BuildSpec.name
    $ProductVersion = $BuildSpec.version

    Install-BuildDependencies -WingetFile "${ScriptHome}/.Wingetfile"

    Push-Location -Stack BuildTemp
    if ( ! ( ( $SkipAll ) -or ( $SkipBuild ) ) ) {
        Ensure-Location $ProjectRoot

        $CmakeArgs = @()
        $CmakeBuildArgs = @()
        $CmakeInstallArgs = @()

        if ( $VerbosePreference -eq 'Continue' ) {
            $CmakeBuildArgs+= ('--verbose')
            $CmakeInstallArgs+= ('--verbose')
        }

        if ( $DebugPreference -eq 'Continue' ) {
            $CmakeArgs += ('--debug-output')
        }

        if ( $Env:CI -ne $null ) {
            switch ( $Env:GITHUB_EVENT_NAME ) {
                pull_request {
                    $BuildConfiguration = 'RelWithDebInfo'
                    $Preset = "windows-ci-${Target}"
                }
                push {
                    if ( $Env:GITHUB_REF_NAME -match '[0-9]+.[0-9]+.[0-9]+(-(rc|beta).+)?' ) {
                        $BuildConfiguration = 'Release'
                        $Preset = "windows-${Target}"
                    } else {
                        $BuildConfiguration = 'RelWithDebInfo'
                        $Preset = "windows-ci-${Target}"
                    }
                }
            }
        } else {
            $BuildConfiguration = 'Release'
            $Preset = "windows-${Target}"
        }

        $CmakeArgs += @(
            '--preset', $Preset
        )

        $CmakeBuildArgs = @(
            '--build'
            '--preset', $Preset
            '--parallel'
            '--', '/consoleLoggerParameters:Summary', '/noLogo'
        )

        $CmakeInstallArgs = @(
            '--install', "build_${Target}"
            '--prefix', "${ProjectRoot}/release/${BuildConfiguration}"
            '--config', $BuildConfiguration
        )

        Log-Group "Configuring ${ProductName}..."
        Invoke-External cmake @CmakeArgs

        Log-Group "Building ${ProductName}..."
        Invoke-External cmake @CmakeBuildArgs
    }
    Log-Group "Install ${ProductName}..."
    Invoke-External cmake @CmakeInstallArgs

    Pop-Location -Stack BuildTemp
    Log-Group
}

Build
