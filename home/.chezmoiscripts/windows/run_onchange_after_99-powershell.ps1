#!/usr/bin/env -S pwsh
#requires -version 7 -modules bootstrap.environment, bootstrap.ux
[CmdletBinding(SupportsShouldProcess)]
param()

$commonParams = $PSBoundParameters

<#
.SYNOPSIS
Disable PowerShell notifications about updates.
#>
function Disable-WorkloadUpdateNotify
{
    Set-EnvironmentVariable -Name 'POWERSHELL_UPDATECHECK' -Value 'off' -Target User @commonParams
}
#
#
#

# NOTE: telemetry is disabled in 10-privacy-settings.ps1
Disable-WorkloadUpdateNotify