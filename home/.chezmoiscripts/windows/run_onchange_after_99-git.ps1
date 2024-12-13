#!/usr/bin/env -S pwsh
#requires -version 7 -modules bootstrap.environment
[CmdletBinding(SupportsShouldProcess)]
param()

$PSDefaultParameterValues['Set-EnvironmentVariable:WhatIf'] = $WhatIfPreference

function Update-GitConfigGlobal
{
    # GITCRAP: Because I symlink %APPDATA%\git to ~\.config\git, Git warns:
    # warning: 'C:\Users\cdonnelly/.config/git/config' was ignored because 'C:\Users\cdonnelly\AppData\Roaming/Git/config' exists.
    # Setting GIT_CONFIG_GLOBAL works around this.
    $GitConfigGlobal = Join-Path $HOME ".config/git/config"
    Set-EnvironmentVariable -Name 'GIT_CONFIG_GLOBAL' -Value $GitConfigGlobal -Target User
}

#
#
#

Update-GitConfigGlobal