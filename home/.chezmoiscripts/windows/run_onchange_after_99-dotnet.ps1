#requires -version 7 -modules bootstrap.environment, bootstrap.ux
[CmdletBinding(SupportsShouldProcess)]
param()

$commonParams = $PSBoundParameters

<#
.SYNOPSIS
Disable checking for workflow updates on running `dotnet`.

.LINK
https://github.com/dotnet/sdk/issues/22571
.LINK
https://stackoverflow.com/a/79073472/17152
#>
function Disable-WorkloadUpdateNotify
{
    Set-EnvironmentVariable -Name 'DOTNET_CLI_WORKLOAD_UPDATE_NOTIFY_DISABLE' -Value 'true' -Target User @commonParams
}

#
#
#

# NOTE: telemetry is disabled in 10-privacy-settings.ps1
Disable-WorkloadUpdateNotify