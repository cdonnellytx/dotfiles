#!/usr/bin/env -S pwsh -NoProfile

if ($bat = Get-Command -Type Application -Name 'bat', 'batcat' -ErrorAction Ignore | Select-Object -First 1)
{
    & $bat cache --build
}