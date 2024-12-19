#requires -Version 7 -Modules bootstrap.registry -RunAsAdministrator

<#
.SYNOPSIS
Enable Developer Mode.
.LINK
https://stackoverflow.com/questions/44158326/win10-how-to-activate-developer-mode-using-powershell-or-cmd-exe
#>
[CmdletBinding(SupportsShouldProcess)]
param()

Confirm-RegistryEntry -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name 'LongPathsEnabled' -PropertyType DWORD -Value 1
