#requires -Version 7 -Modules bootstrap.registry

<#
.SYNOPSIS
Updates clipboard settings.
#>
[CmdletBinding(SupportsShouldProcess)]
param()

# Disable Clipboard "Suggested Actions"
# .LINK https://support.microsoft.com/en-us/windows/use-suggested-actions-on-your-pc-486c0527-3395-4b40-b304-f1e3cbe2f404
Confirm-RegistryEntry -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\SmartActionPlatform\SmartClipboard' -Name 'Disabled' -PropertyType DWORD -Value 1