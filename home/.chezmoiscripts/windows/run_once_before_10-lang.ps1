#requires -version 7 -modules bootstrap.environment

<#
.SYNOPSIS
Set CLI LANG variables.
#>
[CmdletBinding(SupportsShouldProcess)]
param()

process
{
    # POSIX LANG
    Set-EnvironmentVariable 'LANG' 'en_US.UTF-8' -Target User @PSBoundParameters
    Set-EnvironmentVariable 'LC_ALL' 'en_US.UTF-8' -Target User @PSBoundParameters

    # Less
    Set-EnvironmentVariable 'LESSCHARSET' 'UTF-8' -Target User @PSBoundParameters

}