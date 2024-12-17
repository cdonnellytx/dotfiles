#!/usr/bin/env -S pwsh
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
    # GITCRAP: Because I symlink %APPDATA%\git to ~\.config\git, Git warns:
    # warning: 'C:\Users\cdonnelly/.config/git/config' was ignored because 'C:\Users\cdonnelly\AppData\Roaming/Git/config' exists.
    # Setting GIT_CONFIG_GLOBAL works around this.
    Set-EnvironmentVariable -Name 'DOTNET_CLI_WORKLOAD_UPDATE_NOTIFY_DISABLE' -Value 'true' -Target User @commonParams
}

<#
.SYNOPSIS
Disable checking for workflow updates on running `dotnet`.

.LINK
https://github.com/dotnet/sdk/issues/22571
.LINK
https://stackoverflow.com/a/79073472/17152
#>
function Disable-Telemetry
{
    # GITCRAP: Because I symlink %APPDATA%\git to ~\.config\git, Git warns:
    # warning: 'C:\Users\cdonnelly/.config/git/config' was ignored because 'C:\Users\cdonnelly\AppData\Roaming/Git/config' exists.
    # Setting GIT_CONFIG_GLOBAL works around this.
    Set-EnvironmentVariable -Name 'DOTNET_CLI_TELEMETRY_OPTOUT' -Value 'true' -Target User @commonParams -ErrorVariable:err
}

#
#
#

Disable-Telemetry
Disable-WorkloadUpdateNotify