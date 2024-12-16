<#
.SYNOPSIS
Make PowerShell Desktop UTF-8.

.NOTES
PowerShell Core is already UTF-8 (no BOM), but PowerShell Desktop... isn't.
Set output encoding in all possible places.

@see https://stackoverflow.com/a/40098904
@see https://stackoverflow.com/a/5596984
#>
#requires -Version 5.1
#requires -psedition Desktop
Set-StrictMode -Version Latest

# This needs some refinement.
# Can't do *:Encoding anymore because too many commands use it for different things.
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'

# We want UTF-8 (code page 65001), no BOM (preamble length 0).
if ($OutputEncoding.CodePage -ne 65001 -or $OutputEncoding.GetPreamble())
{
    Write-Verbose "Creating UTF-8 encoding without BOM..."
    $Global:OutputEncoding = [Text.UTF8Encoding]::new($false)
}
