#requires -version 7 -modules Microsoft.PowerShell.Utility

using namespace System.Management.Automation

<#
.SYNOPSIS
Pin WinGet app versions.
#>
[CmdletBinding(SupportsShouldProcess)]
param()

$splat = $PSBoundParameters
$splat['ErrorAction'] = [ActionPreference]::Stop

# These apps update on their own and it's easier to just let them.
Lock-WinGet @splat -Id 'Discord.Discord'
Lock-WinGet @splat -Id 'Mozilla.Firefox'
Lock-WinGet @splat -Id 'Microsoft.PowerToys'
Lock-WinGet @splat -Id 'Obsidian.Obsidian'
Lock-WinGet @splat -Id 'SlackTechnologies.Slack'

# These apps update on their own and they range from requiring fiddling to being actively hostile to anything else updating them.
Lock-WinGet @splat -Id 'Logitech.GHUB' -Blocking    # GHUB: actively hostile, will tell you so
