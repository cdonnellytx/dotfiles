#requires -Version 7 -Modules bootstrap.fs, bootstrap.knownfolders, bootstrap.ux, bootstrap.chezmoi

using namespace System.IO

<#
.SYNOPSIS
Modify Windows' default profile locations to call the shared profile in the Unix home directory (~/.config/powershell).

.PARAMETER ConfigPath
The path to the PowerShell "config" directory:
- ~/.config/powershell          Unix (and my profile)
- $DOCUMENTS\PowerShell         Windows (6.0+)
- $DOCUMENTS\WindowsPowerShell  Windows (< 6.0)

This creates stub profile.ps1 files in the two Windows directories to use the shared canonical versions.

.NOTES
Because Documents is typically absorbed into OneDrive or similar now, we cannot rely on symlinks.
#>
[CmdletBinding(SupportsShouldProcess)]
param
(
    [Parameter(Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string] $SourcePath = '~/.config/powershell',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $Documents = (Get-KnownFolder Documents)
)

Set-StrictMode -Version Latest

filter ToPowerShell
{
    $_ -creplace '"', '``"'
}

Write-Header "Connect profile.ps1 from $SourcePath"

Get-ChildItem -LiteralPath $Documents -Include 'PowerShell', 'WindowsPowerShell' | ForEach-Object {
    $Destination = $_
    Confirm-PathIsContainer $Destination -Verbose

    $SourcePath | Get-Item -ErrorAction Stop | Get-ChildItem -Include 'profile.ps1', '*_profile.ps1' | ForEach-Object {
        $sourceItem = $_

        # Alias HOME to ~ because these live in OneDrive and may not be in the same home directory always.
        $sourceProfilePath = Join-Path -Path '~' -ChildPath (Resolve-Path -Relative $sourceItem.FullName -RelativeBasePath $HOME)

        # Generate the expected content.
        $content = @"
`$sharedProfile = `"$($sourceProfilePath | ToPowerShell)`"
if (Test-Path -LiteralPath `$sharedProfile -PathType Leaf)
{
    & `$sharedProfile
}
else
{
    Write-Warning "Shared profile `${sharedProfile} not found."
}
"@
        $destinationItemPath = Join-Path -Path $Destination -ChildPath $sourceItem.Name

        Write-Verbose "Make '${destinationItemPath}' call '${sourceItem}'"
        Enter-Operation "Connect PowerShell profile to '${destinationItemPath}'"

        if ($destinationItem = Get-Item -LiteralPath $destinationItemPath -ErrorAction Ignore)
        {
            if (($destinationItem | Get-Content -Raw) -eq $content)
            {
                Exit-Operation "already exists"
                return
            }

            $destinationItem | Rename-Item -NewName ('{0}.bak.{1:yyyyMMddHHmmss}' -f $destinationItem.Name, [DateTime]::UtcNow)
        }

        Set-Content -LiteralPath $destinationItem -Value $content -ErrorVariable err
        Exit-Operation -Error $err
    }
}

