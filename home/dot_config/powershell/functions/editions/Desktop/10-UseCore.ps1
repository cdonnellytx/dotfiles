<#
.SYNOPSIS
Add PowerShell Core's Modules directories to `$Env:PSModulePath` for PowerShell Desktop.
#>
#requires -version 5.1
#requires -psedition Desktop

using namespace System.IO

Set-StrictMode -Version Latest

# Machine: Try finding the install.
if ($core = AppX\Get-AppxPackage -Name 'Microsoft.PowerShell' -ErrorAction Ignore)
{
    # Core is installed as a Microsoft Store app.
    $coreInstallLocation = $core.InstallLocation
}
else
{
    # Look in default MSI install location for Core.
    $coreInstallLocation = Get-Item -LiteralPath "${env:ProgramFiles}\PowerShell", "${env:ProgramFiles(x86)}\PowerShell" -ErrorAction Ignore |
        Select-Object -First 1 -ExpandProperty FullName
}

if ($coreInstallLocation)
{
    $coreMachine = [Path]::Combine($coreInstallLocation, 'Modules')
}

# User: Assume default (DOCUMENTS\WindowsPowerShell -> DOCUMENTS\PowerShell)
$coreUser = [Path]::GetFullPath([Path]::Combine($profile.CurrentUserAllHosts, '..\..\PowerShell\Modules'))

# Now append user/machine to PSModulePath if not already present.
# (Append so Desktop paths override Core paths.)
# We want PSModulePath;USER;MACHINE
$modulePaths = $env:PSModulePath.Split(';').TrimEnd('\')
foreach ($path in ($coreUser, $coreMachine))
{
    if ($path -and $modulePaths -inotcontains $path)
    {
        $modulePaths += $path
        $env:PSModulePath = "${env:PSModulePath};${path}"
    }
}
