#requires -version 7.0 -modules bootstrap.environment

<#
.SYNOPSIS
Adds 7-Zip to user PATH so `7z` is available.
#>
[CmdletBinding(SupportsShouldProcess)]
param()

$7zipPath = Get-ItemPropertyValue -LiteralPath 'HKLM:\Software\7-Zip' -Name 'Path'
if (!$7zipPath)
{
    Write-Error -Category InvalidOperation "7zip does not appear to be installed; cannot continue."
    exit 1
}

Add-PathVariable -Name PATH -Target User -Value $7zipPath
