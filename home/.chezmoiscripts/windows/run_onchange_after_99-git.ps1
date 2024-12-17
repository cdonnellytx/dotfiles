#!/usr/bin/env -S pwsh
#requires -version 7 -modules bootstrap.environment, bootstrap.ux
[CmdletBinding(SupportsShouldProcess)]
param()

$commonParams = $PSBoundParameters

function Update-GitConfigCoreLongPathsSetting
{
    # https://stackoverflow.com/questions/22575662/filename-too-long-in-git-for-windows
    Invoke-Operation 'git: core.longpaths=true' {
        Get-Command 'git' -ErrorAction Stop >$null
        $value = git config --system core.longpaths
        if ($value -eq 'true')
        {
            return Skip-Operation 'same value'
        }

        sudo git config --system core.longpaths true
    }
}

function Update-GitConfigGlobal
{
    # GITCRAP: Because I symlink %APPDATA%\git to ~\.config\git, Git warns:
    # warning: 'C:\Users\cdonnelly/.config/git/config' was ignored because 'C:\Users\cdonnelly\AppData\Roaming/Git/config' exists.
    # Setting GIT_CONFIG_GLOBAL works around this.
    $GitConfigGlobal = Join-Path $HOME ".config/git/config"
    Set-EnvironmentVariable -Name 'GIT_CONFIG_GLOBAL' -Value $GitConfigGlobal -Target User @commonParams -ErrorVariable:err
}

#
#
#

Update-GitConfigCoreLongPathsSetting
Update-GitConfigGlobal