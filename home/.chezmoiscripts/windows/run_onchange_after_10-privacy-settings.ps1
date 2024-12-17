#requires -version 7 -modules bootstrap.registry
[CmdletBinding(SupportsShouldProcess)]
param()

$commonParams = $PSBoundParameters

<#
.SYNOPSIS
Privacy: Let apps use my advertising ID: Disable
#>
function Disable-AdvertisingId
{
    # Stolen from https://gist.github.com/NickCraver/7ebf9efbfd0c3eab72e9
    Confirm-RegistryEntry -LiteralPath HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo -Name 'Enabled' -Type DWord -Value 0 @commonParams
}

<#
.SYNOPSIS
Disables the Bing Internet Search when using the search field in the Taskbar or Start Menu.
#>
function Disable-BingSearch
{
    [version] $osVersion = [System.Environment]::OSVersion.Version
    [version] $windows2004Version = '10.0.19041'

    if ($osVersion -ge $windows2004Version)
    {
        Confirm-RegistryEntry -LiteralPath 'HKCU:\Software\Policies\Microsoft\Windows\Explorer' -Name 'DisableSearchBoxSuggestions' -Value 1 -PropertyType 'DWORD' @commonParams
    }
    else
    {
        Confirm-RegistryEntry -LiteralPath 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search' -Name 'BingSearchEnabled' -Value 0 -PropertyType 'DWORD' @commonParams
    }
}

#
# Main
#
Disable-AdvertisingId
Disable-BingSearch
