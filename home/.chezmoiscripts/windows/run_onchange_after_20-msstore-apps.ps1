#requires -version 7 -modules bootstrap.winget

<#
.SYNOPSIS
Install MSStore apps.
.NOTES
WinGet can install store apps, but will not include them in exports.
#>
[CmdletBinding(SupportsShouldProcess)]
param()

@(
    @{ Id = '9mz1snwt0n5d'; Source = 'msstore'; Description = "PowerShell" }
    @{ Id = '9p7knl5rwt25'; Source = 'msstore'; Description = "Sysinternals Suite" }
) | Install-ViaWinGet @PSBoundParameters -InformationAction:Continue
