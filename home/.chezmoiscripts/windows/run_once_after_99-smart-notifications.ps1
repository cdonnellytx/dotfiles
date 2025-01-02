#requires -Version 7 -Modules bootstrap.registry

<#
.SYNOPSIS
Configure notification preferences.

#>
[CmdletBinding(SupportsShouldProcess)]
param()

# Turn off the "Smart" opt-out that asks you periodically if you want to turn off notifications for the Snipping Tool and other core things that you absolutely need it to.
# .LINK https://superuser.com/questions/1820188/turn-off-all-notifications-for-notification-suggestions
Confirm-RegistryProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.ActionCenter.SmartOptOut' -Name 'Enabled' -PropertyType DWORD -Value 0
