#requires -version 7 -modules bootstrap.winget, Microsoft.PowerShell.Utility

using namespace System.Management.Automation

<#
.SYNOPSIS
Pin WinGet app versions.
#>
[CmdletBinding(SupportsShouldProcess)]
param()

filter WhereInstalled
{
    $_ | ConvertTo-WinGetItem | Where-Object { Test-WinGetItem $_ }
}

# These apps update on their own and it's easier to just let them, but they are safe to update via winget.
@(
    'Discord.Discord'
    'GnuPG.GnuPG'               # GnuPG: is installed by Gpg4Win, no need to check for both.
    'Microsoft.PowerToys'
    'Microsoft.VisualStudioCode'
    'Mozilla.Firefox'
    'Obsidian.Obsidian'
    'SlackTechnologies.Slack'
) | WhereInstalled | Limit-WinGetPackage

# These apps update on their own and they range from being superior at their own updates tos requiring fiddling to being actively hostile to anything else updating them.
@(
    'Logitech.GHUB'
) | WhereInstalled | Limit-WinGetPackage -Blocking
