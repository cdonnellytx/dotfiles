#requires -Version 5.1
#requires -Modules Microsoft.PowerShell.Utility
using namespace System.IO

<#
.SYNOPSIS
Custom formats and types.
#>
param()

# LATER: resolve this more elegantly
$RepoRoot = [Path]::GetDirectoryName([Path]::GetDirectoryName($PSScriptRoot))

$FormatsRoot = [Path]::Combine($RepoRoot, 'formats')
if (Test-Path -LiteralPath $FormatsRoot)
{
    Write-Verbose "Update formats"
    Update-FormatData -PrependPath:([Directory]::GetFiles($FormatsRoot, '*.ps1xml'))
}

$TypesRoot = [Path]::Combine($RepoRoot, 'types')
if (Test-Path -LiteralPath $TypesRoot)
{
    Write-Verbose "Update types"
    Update-TypeData -PrependPath:([Directory]::GetFiles($TypesRoot, '*.ps1xml'))
}
