#requires -Version 7 -Modules bootstrap.explorer, bootstrap.registry

<#
.SYNOPSIS
Sets keyboard delay in the registry.
Requires reboot OR opening Control Panel to work.
#>
[CmdletBinding(SupportsShouldProcess)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', 'Global:restartExplorer')]
param
(
    # The keyboard delay (0 = fastest, 3 = slowest)
    [ValidateRange(0, 3)]
    [int] $Delay = 0,

    [ValidateRange(0, 31)]
    [int] $Speed = 31
)

$global:restartExplorer = 0
$onChange = { $global:restartExplorer++ }

Confirm-RegistryProperty -LiteralPath 'HKCU:\Control Panel\Keyboard' -Name 'KeyboardDelay' -PropertyType DWORD -Value $Delay -OnChange:$onChange
Confirm-RegistryProperty -LiteralPath 'HKCU:\Control Panel\Keyboard' -Name 'KeyboardSpeed' -PropertyType DWORD -Value $Speed -OnChange:$onChange

if ($global:restartExplorer -gt 0)
{
    Restart-Explorer
}
