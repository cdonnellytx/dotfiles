#requires -version 7 -modules bootstrap.registry -RunAsAdministrator

<#
.SYNOPSIS
Enable privacy settings.
#>
[CmdletBinding(SupportsShouldProcess)]
param()

Set-StrictMode -Version Latest

$commonParams = $PSBoundParameters

<#
.SYNOPSIS
Privacy: Let apps use my advertising ID: Disable
#>
function Disable-AdvertisingId
{
    # Stolen from https://gist.github.com/NickCraver/7ebf9efbfd0c3eab72e9
    Confirm-RegistryProperty -LiteralPath 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo' -Name 'Enabled' -Type DWord -Value 0 @commonParams
}

<#
.SYNOPSIS
Disables the Bing Internet Search when using the search field in the Taskbar or Start Menu.
#>
function Disable-BingSearch
{
    [version] $osVersion = [System.Environment]::OSVersion.Version

    if ($osVersion -ge <# Windows 10 20H1 ("2004") #> '10.0.19041')
    {
        Confirm-RegistryProperty -LiteralPath 'HKCU:\Software\Policies\Microsoft\Windows\Explorer' -Name 'DisableSearchBoxSuggestions' -Value 1 -PropertyType 'DWORD' @commonParams
    }
    else
    {
        Confirm-RegistryProperty -LiteralPath 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search' -Name 'BingSearchEnabled' -Value 0 -PropertyType 'DWORD' @commonParams
    }
}

#
# Main
#
Disable-AdvertisingId
Disable-BingSearch

Set-EnvironmentVariable -Name 'DOTNET_CLI_TELEMETRY_OPTOUT' -Value 'true' -Target Machine @commonParams
Set-EnvironmentVariable -Name 'POWERSHELL_TELEMETRY_OPTOUT' -Value 'true' -Target Machine @commonParams
