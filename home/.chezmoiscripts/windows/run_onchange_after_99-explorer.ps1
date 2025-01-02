#requires -version 7 -modules bootstrap.explorer, bootstrap.registry

<#
.SYNOPSIS
Sets File Explorer options.
#>
[CmdletBinding(SupportsShouldProcess)]
param()

Set-StrictMode -Version Latest

# Pulled from BoxStarter.WinConfig, which unfortunately relies on Get-WMIObject
if (!$PSCmdlet.ShouldProcess("Explorer", "Set Options"))
{
    return
}

$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer'
$advancedKey = "${key}\Advanced"
$cabinetStateKey = "${key}\CabinetState"
#$ribbonKey = "${key}\Ribbon"

# -EnableShowFileExtensions
Confirm-RegistryProperty -LiteralPath $advancedKey -Name 'HideFileExt' -PropertyType 'DWORD' -Value 0
# -EnableShowHiddenFilesFoldersDrives
Confirm-RegistryProperty -LiteralPath $advancedKey -Name 'Hidden' -PropertyType 'DWORD' -Value 1
# -EnableShowProtectedOSFiles
Confirm-RegistryProperty -LiteralPath $advancedKey -Name 'ShowSuperHidden' -PropertyType 'DWORD' -Value 1
# -EnableShowFullPathInTitleBar
Confirm-RegistryProperty -LiteralPath $cabinetStateKey -Name 'FullPath' -PropertyType 'DWORD' -Value 1

# Menu alignment: Left-align, not right-align, don't care about handedness on touch screens.
# (Done here b/c it requires an Explorer restart.)
Confirm-RegistryProperty -LiteralPath 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows\' -Name 'MenuDropAlignment' -PropertyType 'DWORD' -Value 0

if ([System.Environment]::OSVersion.Version -ge '10.0.22000.0')
{
    # Context menu in Windows 11: show all items
    # @see https://twitter.com/Nick_Craver/status/1494661475553714177
    Confirm-RegistryProperty -LiteralPath 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32' -Name '(default)' -PropertyType 'String' -Value ''

    # Move taskbar icon alignment to the left
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAl" -Value 0
}

Restart-Explorer
