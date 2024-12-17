#requires -version 7 -modules bootstrap.psresource

using namespace Microsoft.WinGet.Client.PSObjects

<#
.SYNOPSIS
Install and configure PowerShell modules used on all or most environments.
#>
[CmdletBinding(SupportsShouldProcess)]
param()

@(
    @{
        Name = 'Microsoft.WinGet.Client'
        Condition = $IsWindows
        SkipMessage = 'Windows only'
    }
    'nvm'
    'Pansies'
    'PsIni'
    'wsl'
    'z'
) | Install-ViaPSResourceGet -ErrorAction Stop
