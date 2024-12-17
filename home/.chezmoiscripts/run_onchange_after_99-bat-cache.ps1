#!/usr/bin/env -S pwsh -NoProfile
#requires -version 7 -modules bootstrap.ux

if ($bat = Get-Command -Type Application -Name 'bat', 'batcat' -ErrorAction Ignore | Select-Object -First 1)
{
    Invoke-Operation 'bat: Rebuild cache' { & $bat cache --build | Write-Verbose }
}