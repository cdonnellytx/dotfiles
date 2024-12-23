#requires -version 7 -modules bootstrap.environment

<#
.SYNOPSIS
Add common paths to user-level PATH.
#>
[CmdletBinding(SupportsShouldProcess)]
param()

$paths = @(
    (Join-Path $HOME 'bin'),
    (Join-Path $HOME '.local/bin')
)

Add-PathVariable @PSBoundParameters -Name 'PATH' -Target User -Value $paths
