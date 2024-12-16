#requires -Version 7 -modules bootstrap.ux

using namespace Microsoft.WinGet.Client.PSObjects

[CmdletBinding(SupportsShouldProcess)]
param()

# Install-PSResource will blindly install the latest.
[string[]] $moduleNames = @(
    'Microsoft.WinGet.Client',
    'PsIni',
    'wsl',
    'z'
)

$moduleNames | ForEach-Object {
    Enter-Operation "Installing module '${_}'"
    if ($installedModule = Get-PSResource -Name $_ -ErrorAction Ignore)
    {
        Exit-Operation "v$($installedModule.Version) was already installed"
        return
    }

    Install-PSResource -Name $_ -ErrorVariable err
    Exit-Operation -Error:$err
}

