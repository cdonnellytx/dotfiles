#!/usr/bin/env -S pwsh -NoProfile

<#
.SYNOPSIS
Fix Discord's version in the registry
.NOTES

Discord's autoupdater is stupid and doesn't update DisplayVersion in the registry,
causing WinGet to forever think it's out-of-date.
Worse, running `winget update` to update Discord invariably fails or simply does not update the registry.
Hence, this program.
#>
using namespace System
using namespace System.Management.Automation

[CmdletBinding(SupportsShouldProcess)]
param()

if (!$IsWindows)
{
    throw [PlatformNotSupportedException]::new()
}

[PSCustomObject[]] $items = @(
    @{
        Name = 'Discord'
        Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Discord'
        FindBy = 'InstallLocation'
        ExecutableName = 'discord.exe'
    }
    @{
        Name = 'Obsidian'
        Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\bd400747-f0c1-5638-a859-982036102edf'
        FindBy = 'DisplayIcon'
    }
)

$items | ForEach-Object {
    $app = $_

    # Find the item in the registry.
    if (!($registry = Get-ItemProperty -LiteralPath:$app.Path))
    {
        Write-Error -Category ObjectNotFound -Message "Install information not found in registry.  For application: $($app.Name)"
        return
    }

    # Get the executable.
    $executables = switch ($app.FindBy)
    {
        'InstallLocation'
        {
            Get-ChildItem -Recurse -LiteralPath $registry.InstallLocation -Depth 2 -Include $app.ExecutableName |
                ForEach-Object { Get-Command $_.FullName }
        }

        'DisplayIcon'
        {
            $registry.DisplayIcon -split ',', 2 | Select-Object -First 1 | Get-Command
        }

        default
        {
            Write-Error -Category NotImplemented -Message "FindBy type '${_}' not implemented.  For application: $($app.Name)"
            return
        }
    }

    $executable = $executables |
        Select-Object -Property Name, Path, @{ Name = 'Version'; Expression = {
            $result = $null
            if ([semver]::TryParse($_.FileVersionInfo.ProductVersion, [ref] $result) -or [semver]::TryParse($_.FileVersionInfo.FileVersion, [ref] $result))
            {
                return $result
            }

            # System.Version: cast to semver
            if ($_.Version)
            {
                return [semver] $_.Version
            }
        } } |
        Sort-Object -Descending -Property Version |
        Select-Object -First 1

    if (!$executable)
    {
        Write-Error -Category ObjectNotFound -Message "No executable found.  For application: $($app.Name)"
        return
    }

    [semver] $registryVersion = $registry.DisplayVersion
    switch ($executable.Version)
    {
        { $_ -lt $registryVersion }
        {
            Write-Error -Category InvalidOperation "$($executable.Name) version $($executable.Version) found, but it is older than the registry value (${registryVersion}).  For application: $($app.Name)"
            return
        }

        { $_ -eq $registryVersion }
        {
            Write-Verbose "$($executable.Name) and registry have the same version (${_}).  For application: $($app.Name)"
            return
        }

        default
        {
            if ($PSCmdlet.ShouldProcess("application: $($app.Name), current: ${registryVersion}, new: ${_}", "Update version in registry"))
            {
                $registry | Set-ItemProperty -Name 'DisplayVersion' -Value ($_.ToString())
            }
        }
    }
}
