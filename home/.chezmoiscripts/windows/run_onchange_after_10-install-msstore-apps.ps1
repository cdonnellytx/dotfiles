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

class MSStoreItem
{
    # .NOTES
    # MSCRAP: Only Install-WinGetPackage recognizes MSStore apps by Id.
    # Everything else recognizes it by "Moniker".
    [string] $Moniker
    [string] $Source = 'msstore'

    # A name for documentation purposes.  Not WinGetPackage name.
    hidden [string] $Description

    # An alternate WinGetPackage.ID from source= if known.
    hidden [string] $AlternateId

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

[MSStoreItem[]] $storeApps = @(
    [MSStoreItem]::new('9mz1snwt0n5d', 'PowerShell')
    [MSStoreItem]::new('9p7knl5rwt25', 'Sysinternals Suite')
    [MSStoreItem] @{
        Moniker = 'XP99C9G0KRDZ27'
        Description = '1Password'
        AlternateId = 'AgileBits.1Password'
    }
)

$installedStoreApps = $storeApps | Get-WinGetPackage -MatchOption:Equals
$installedWinGetApps = $storeApps | Where-Object AlternateId | ForEach-Object { Get-WinGetPackage -Source 'winget' -Id:$_.AlternateId }
$storeAppsToInstall = $storeApps | Where-Object Moniker -notin $installedStoreApps.Id | Where-Object AlternateId -notin $installedWinGetApps.Id

Write-Information "Installed apps:$($installedStoreApps + $installedWinGetApps | Out-String)"

if ($storeAppsToInstall)
{
    Write-Information "To install: $($storeAppsToInstall | Out-String)"
    # MSCRAP: Microsoft.WinGet.Client\Install-WinGetPackage 1.10.90 _still_ doesn't honor `-WhatIf`.
    if ($PSCmdlet.ShouldProcess("apps: $($storeAppsToInstall)", "Install WinGet packages"))
    {
        $appsToInstall | Install-WinGetPackage
    }
}
