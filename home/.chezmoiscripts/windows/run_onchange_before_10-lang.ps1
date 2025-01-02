#requires -version 7 -modules bootstrap.environment

<#
.SYNOPSIS
Set CLI LANG variables.
#>
[CmdletBinding(SupportsShouldProcess)]
param()

Set-StrictMode -Version Latest

$charset = 'UTF-8'
$locale = 'en_US.UTF-8'

# POSIX LANG
Set-EnvironmentVariable @PSBoundParameters -Target User -Name 'LANG' -Value $locale
Set-EnvironmentVariable @PSBoundParameters -Target User -Name 'LC_ALL' -Value $locale

# Less
Set-EnvironmentVariable @PSBoundParameters -Target User -Name 'LESSCHARSET' -Value $charset
