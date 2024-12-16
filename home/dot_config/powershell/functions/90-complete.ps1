<#
.SYNOPSIS
Argument completion (shared)
#>
Set-StrictMode -Version Latest
New-Variable -Name 'DebugArgumentCompleter' -Description 'Hashtable for debugging argument completers' -Scope Global -Option ReadOnly -Value @{}