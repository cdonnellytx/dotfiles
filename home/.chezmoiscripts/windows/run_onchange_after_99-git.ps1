#!/usr/bin/env -S pwsh
#requires -version 7 -modules bootstrap.environment, bootstrap.ux
[CmdletBinding(SupportsShouldProcess)]
param()

$commonParams = $PSBoundParameters

function Update-GitConfigGlobal
{
    # GITCRAP: Because I symlink %APPDATA%\git to ~\.config\git, Git warns:
    # warning: 'C:\Users\cdonnelly/.config/git/config' was ignored because 'C:\Users\cdonnelly\AppData\Roaming/Git/config' exists.
    # Setting GIT_CONFIG_GLOBAL works around this.
    $GitConfigGlobal = Join-Path $HOME ".config/git/config"
    Enter-Operation 'Set GIT_CONFIG_GLOBAL'
    Set-EnvironmentVariable -Name 'GIT_CONFIG_GLOBAL' -Value $GitConfigGlobal -Target User @commonParams -ErrorVariable:err
    Exit-Operation -Error:$err
}

#
#
#

Update-GitConfigGlobal