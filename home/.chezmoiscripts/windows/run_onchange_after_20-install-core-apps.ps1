#requires -version 7 -modules bootstrap.ux, bootstrap.winget

using namespace Microsoft.WinGet.Client.PSObjects

[CmdletBinding(SupportsShouldProcess)]
param()

@(
    @{ Id = '9mz1snwt0n5d'; Source = 'msstore'; Description = "PowerShell" }
    @{ Id = '9p7knl5rwt25'; Source = 'msstore'; Description = "Sysinternals Suite" }

    'AgileBits.1Password'
    'Git.Git'
    'Microsoft.WindowsTerminal'
    'Mozilla.Firefox'
) | Install-ViaWinGet @PSBoundParameters -InformationAction:Continue
