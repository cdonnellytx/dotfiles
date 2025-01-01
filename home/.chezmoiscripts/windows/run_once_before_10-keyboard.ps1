#requires -Version 7 -Modules bootstrap.registry

<#
.SYNOPSIS
Sets keyboard delay in the registry.
Requires reboot OR opening Control Panel to work.
#>
[CmdletBinding(SupportsShouldProcess)]
param
(
    # The keyboard delay (0 = fastest, 3 = slowest)
    [ValidateRange(0, 3)]
    [int] $Delay = 0,

    [ValidateRange(0, 31)]
    [int] $Speed = 31
)

# Keyboard delay
# 0..3 (faster..slower)
$script:restartExplorer = $false
$onChange = { $script:restartExplorer = $true }

Confirm-RegistryEntry -LiteralPath 'HKCU:\Control Panel\Keyboard' -Name 'KeyboardDelay' -PropertyType DWORD -Value $Delay -OnChange:$onChange
Confirm-RegistryEntry -LiteralPath 'HKCU:\Control Panel\Keyboard' -Name 'KeyboardSpeed' -PropertyType DWORD -Value $Speed -OnChange:$onChange

if ($script:restartExplorer)
{
    Stop-Process -Name explorer
}
