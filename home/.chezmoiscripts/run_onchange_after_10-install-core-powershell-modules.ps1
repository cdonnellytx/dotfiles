#requires -version 7 -modules bootstrap.powershell

using namespace Microsoft.WinGet.Client.PSObjects

<#
.SYNOPSIS
Install and configure PowerShell modules used on all or most environments.
#>
[CmdletBinding(SupportsShouldProcess)]
param()

$modules = @(
    @{
        Name = 'Microsoft.WinGet.Client'
        Condition = $IsWindows
        SkipMessage = 'Windows only'
    }
    'nvm'
    'PsIni'
    'wsl'
    'z'
)

$modules | Install-ViaPSResourceGet -ErrorAction Stop
