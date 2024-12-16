#requires -Version 7 -Modules bootstrap.fs, bootstrap.knownfolders, bootstrap.ux, bootstrap.chezmoi

using namespace System.IO

<#
.SYNOPSIS
Modify default profile locations to call the shared profile in this repository.

.PARAMETER ConfigPath
The path to the PowerShell "config" directory:
- ~/.config/powershell          Unix (and my profile)
- $DOCUMENTS\PowerShell         Windows (6.0+)
- $DOCUMENTS\WindowsPowerShell  Windows (< 6.0)

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
        $destinationItem = Join-Path -Path $Destination -ChildPath $sourceItem.Name

        Write-Verbose "Make '${destinationItem}' call '${sourceItem}'"
        Enter-Operation "Connect PowerShell profile to '${destinationItem}'"

        if (Test-Path -LiteralPath $destinationItem)
        {
            if (Get-Content -LiteralPath $destinationItem -Raw | Where-Object { $_.Contains($content) })
            {
                Exit-Operation "already exists"
                return
            }
        }

        Out-File -LiteralPath $destinationItem -Append -InputObject $content -ErrorVariable err
        Exit-Operation -Error $err
    }
}

