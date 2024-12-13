#requires -Version 7 -modules Microsoft.WinGet.Client, bootstrap.ux
[CmdletBinding(SupportsShouldProcess)]
param()

$PSDefaultParameterValues['Get-WinGetPackage:MatchOption'] = 'Equals'
$PSDefaultParameterValues['Install-WinGetPackage:WhatIf'] = $WhatIfPreference
if ($Env:CHEZMOI_VERBOSE -eq 1)
{
    $PSDefaultParameterValues['*:InformationAction'] = 'Continue'
    $PSDefaultParameterValues['*:Verbose'] = $true
}

class WinGetItemBase
{
}

# Sourced from WinGet explicitly
class WinGetItem : WinGetItemBase
{
    [string] $Id
    [string] $Source = 'winget'
    WinGetItem() {}

    WinGetItem([string] $Id)
    {
        $this.Id = $Id
    }

    [string] ToString()
    {
        return $this.Id
    }
}

class MSStoreItem : WinGetItemBase
{
    # .NOTES
    # MSCRAP: Only Install-WinGetPackage recognizes MSStore apps by Id.
    # Everything else recognizes it by "Moniker".
    [string] $Moniker
    [string] $Source = 'msstore'

    # A name for documentation purposes.  Not WinGetPackage name.
    hidden [string] $Description

    MSStoreItem() {}

    MSStoreItem([string] $Moniker)
    {
        $this.Moniker = $Moniker
    }

    MSStoreItem([string] $Moniker, [string] $Description)
    {
        $this.Moniker = $Moniker
        $this.Description = $Description
    }

    [string] ToString()
    {
        if ($this.Description)
        {
            return '"{0}" (id: {1})' -f $this.Description, $this.Moniker
        }
        return $this.Moniker
    }
}

$apps = @(
    [MSStoreItem]::new('9mz1snwt0n5d', 'PowerShell')
    [MSStoreItem]::new('9p7knl5rwt25', 'Sysinternals Suite')

    # MSCRAP: I tried installing 1Password from MSStore but it kept installing the main WinGet instance
    # -and- saying it had installed -both-, though the Store itself says otherwise.
    # So just install the "normal" item.
    # NOTE: This did not happen with PowerShell, I am not sure why.
    [WinGetItem]::new('AgileBits.1Password')
)

$installedApps = $apps | Get-WinGetPackage -MatchOption:Equals
$appsToInstall = $apps | Where-Object Id -notin $installedApps.Id | Where-Object Moniker -notin $installedApps.Id

Write-Information "Installed apps:$($installedApps | Out-String)"

if ($appsToInstall)
{
    Write-Information "To install: $($appsToInstall | Out-String)"
    # MSCRAP: Microsoft.WinGet.Client\Install-WinGetPackage 1.10.90 _still_ doesn't honor `-WhatIf`.
    if ($PSCmdlet.ShouldProcess("apps: $($appsToInstall)", "Install WinGet packages"))
    {
        $appsToInstall | Install-WinGetPackage -ErrorAction Stop
    }
}
