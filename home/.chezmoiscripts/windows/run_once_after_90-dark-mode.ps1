#requires -Version 7 -Modules bootstrap.registry

<#
.SYNOPSIS
Updates light/dark mode.
.LINK
https://appuals.com/change-dark-light-mode-windows-11/#:~:text=Enable%20Light%20or%20Dark%20Mode,open%20up%20the%20Settings%20menu.&text=Note%3A%20If%20you%20select%20Light,Windows%20Mode%20and%20App%20Mode
#>
[CmdletBinding(SupportsShouldProcess)]
param
(
    [switch] $light
)

# The value is 0 for dark, 1 for light.
$value = [int] [bool] $light

Confirm-RegistryEntry -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'AppsUseLightTheme' -PropertyType DWORD -Value $value
Confirm-RegistryEntry -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'SystemUsesLightTheme' -PropertyType DWORD -Value $value