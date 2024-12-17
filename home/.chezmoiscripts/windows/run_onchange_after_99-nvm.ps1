#!/usr/bin/env -S pwsh -NoProfile
#requires -Version 7 -Module bootstrap.environment, bootstrap.knownfolders

using namespace System

<#
.SYNOPSIS
Set NVM_SYMLINK.
#>
[CmdletBinding(SupportsShouldProcess)]
param()

Set-StrictMode -Version Latest

function Update-NvmSymlink
{
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $UserProgramFiles = Get-KnownFolder -Name UserProgramFiles
    $SymlinkPath = Join-Path $UserProgramFiles 'nodejs'

    Set-EnvironmentVariable -Name 'NVM_SYMLINK' -Value $SymlinkPath -Target User
}

function Update-NvmModuleInstallLocation
{
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        [Parameter(Mandatory)]
        [string] $InstallLocation
    )

    if (!(Get-Command -Name 'Get-NodeInstallLocation'))
    {
        return
    }

    # nvm module exists.
    $CurrentValue = Get-NodeInstallLocation
    if ($CurrentValue -eq $InstallLocation)
    {
        Write-Verbose "nvm module InstallLocation is desired value '${CurrentValue}'"
        return
    }

    if (!$PSCmdlet.ShouldProcess("old path: '${CurrentValue}', new path: ${InstallLocation}", "Update nvm module InstallLocation"))
    {
        return
    }

    Invoke-Operation "Update nvm module install location" {
        Set-NodeInstallLocation -WhatIf:$WhatIfPreference -Path:$InstallLocation -Confirm:$false

        switch (Get-NodeInstallLocation)
        {
            $InstallLocation
            {
                # We're done.
                return
            }
            "${InstallLocation}\.nvm"
            {
                # BUGBUG: Set-NodeInstallLocation as of 2.5.4 tacks an ".nvm" subdirectory on the end :(
                $module = Get-Module -Name 'nvm'
                $settingsPath = Join-Path $module.ModuleBase 'settings.json'
                Copy-Item -LiteralPath:$settingsPath -Destination:"${settingsPath}.bak"
                $json = Get-Content -LiteralPath:$settingsPath | ConvertFrom-Json -AsHashtable
                $json.InstallPath = $InstallLocation
                Set-Content -LiteralPath:$settingsPath -Value ($json | ConvertTo-Json -Depth 10)
                if ($InstallLocation -eq (Get-NodeInstallLocation))
                {
                    return
                }
            }
        }

        # Nope
        Write-Error "Unable to update node install location (expected '${InstallLocation}' but actually set '$(Get-NodeInstallLocation)')"
    }
}

#
# Main
#
$nvmExe = Get-Command -CommandType Application -Name 'nvm' -ErrorAction Ignore
if (!$nvmExe)
{
    Write-Verbose "nvm.exe not installed"
    return
}

Update-NvmSymlink
Update-NvmModuleInstallLocation -InstallLocation:(($nvmExe | Get-Item).Directory.FullName)
