#requires -version 7 -modules bootstrap.chezmoi, bootstrap.winget, Microsoft.PowerShell.Utility

<#
.SYNOPSIS
Import WinGet installed apps.
Will install apps if not found but not upgrade them.
.NOTES
WinGet can install store apps, but will not include them in exports.
#>
[CmdletBinding(SupportsShouldProcess)]
param()

$workingTree = Get-ChezmoiWorkingTree
$wingetManifestTemplate = Join-Path $workingTree 'assets/winget.json.tmpl' | Get-Item -ErrorAction Stop

$wingetManifest = New-TemporaryFile -WhatIf:$false
$wingetManifestTemplate | Get-Content -Raw | chezmoi execute-template --output $wingetManifest

Write-Verbose "winget file template at ${wingetManifest}"

Invoke-Operation "Import WinGet manifest" -WhatIf:$WhatIfPreference {
    # MSCRAP: Microsoft.WinGet.Client has export but NOT import (1.10.40-beta)
    winget import --import-file $wingetManifest --no-upgrade --accept-package-agreements --accept-source-agreements --disable-interactivity
    if (!$?)
    {
        Write-Error ("winget exited with code 0x{0:X8}" -f $LASTEXITCODE)
    }
}