#requires -Version 7 -Modules bootstrap.chezmoi, bootstrap.registry -RunAsAdministrator

<#
.SYNOPSIS
Enable Developer Mode and related settings.
.LINK
https://stackoverflow.com/questions/44158326/win10-how-to-activate-developer-mode-using-powershell-or-cmd-exe
#>
[CmdletBinding(SupportsShouldProcess)]
param()

# Developer mode
Confirm-RegistryEntry -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' -Name 'AllowDevelopmentWithoutDevLicense' -PropertyType DWORD -Value 1

# Sudo (Windows 11 24H2 and later)
if ((Get-ChezmoiData).chezmoi.windowsVersion.currentBuild -ge 26052)
{
    Confirm-RegistryEntry -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Sudo' -Name 'Enabled' -PropertyType DWORD -Value 3
}
