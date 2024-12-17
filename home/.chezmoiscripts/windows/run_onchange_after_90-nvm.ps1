#requires -version 7 -modules bootstrap.environment, bootstrap.knownfolders, nvm

using namespace System

<#
.SYNOPSIS
Install and configure NVM for Windows.

.LINK
https://github.com/coreybutler/nvm-windows
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
    param()

    $nvmExe = Get-Command -Type Application -Name 'nvm' -ErrorAction Stop | Get-Item
    $exeInstallLocation = $nvmExe.Directory.FullName    # nvm module exists.

    $moduleInstallLocation = Get-NodeInstallLocation
    if ($moduleInstallLocation -eq $exeInstallLocation)
    {
        Write-Verbose "nvm module exeInstallLocation is desired value '${moduleInstallLocation}'"
        return
    }

    if (!$PSCmdlet.ShouldProcess("old path: '${moduleInstallLocation}', new path: ${exeInstallLocation}", "Update nvm module exeInstallLocation"))
    {
        return
    }

    Invoke-Operation "Update nvm module install location" {
        Set-NodeInstallLocation -WhatIf:$WhatIfPreference -Path:$exeInstallLocation -Confirm:$false

        switch (Get-NodeInstallLocation)
        {
            $exeInstallLocation
            {
                # We're done.
                return
            }
            "${exeInstallLocation}\.nvm"
            {
                # BUGBUG: Set-NodeInstallLocation as of 2.5.4 tacks an ".nvm" subdirectory on the end :(
                $module = Get-Module -Name 'nvm'
                $settingsPath = Join-Path $module.ModuleBase 'settings.json'
                Copy-Item -LiteralPath:$settingsPath -Destination:"${settingsPath}.bak"
                $json = Get-Content -LiteralPath:$settingsPath | ConvertFrom-Json -AsHashtable
                $json.InstallPath = $exeInstallLocation
                Set-Content -LiteralPath:$settingsPath -Value ($json | ConvertTo-Json -Depth 10)
                if ($exeInstallLocation -eq (Get-NodeInstallLocation))
                {
                    return
                }
            }
        }

        # Nope
        Write-Error "Unable to update node install location (expected '${exeInstallLocation}' but actually set '$(Get-NodeInstallLocation)')"
    }
}

#
# Main
#

Update-PathVariable PATH

Update-NvmSymlink
Update-NvmModuleInstallLocation
