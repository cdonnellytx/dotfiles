#!/usr/bin/env -S pwsh -NoProfile

<#
.SYNOPSIS
Updates any local source control repositories.

.DESCRIPTION
Updates any local Subversion or Git repositories.
#>

#Requires -Version 5.0
using namespace System.Collections.Generic;
using namespace System.Management.Automation;
using namespace System.IO;

[CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Default')]
param
(
    # Specifies a path to one or more locations. Wildcards are permitted. The default location is the current directory (.).
    [Parameter(
        Position = 0,
        Mandatory = $false,
        ParameterSetName = "Default",
        ValueFromPipeline = $true,
        ValueFromPipelineByPropertyName = $true
    )]
    [ValidateNotNullOrEmpty()]
    [SupportsWildcards()]
    [string[]] $Path = '.',

    # Specifies a path to one or more locations. Unlike the Path parameter, the value of the LiteralPath parameter is used exactly as it is typed. No characters are interpreted as wildcards. If the path includes escape characters, enclose it in single quotation marks. Single quotation marks tell Windows PowerShell not to interpret any characters as escape sequences.
    [Parameter(
        Mandatory = $true,
        ParameterSetName = "LiteralPath",
        ValueFromPipelineByPropertyName = $true
    )]
    [Alias("PSPath")]
    [ValidateNotNullOrEmpty()]
    [string[]] $LiteralPath,

    # Recurse at most this many levels.  Set to 0 to disable recursion.
    [Parameter()]
    [int] $Depth = 4,

    # For git, fetches from and integrates each local repository with the associated remote repository.  Not used by Subversion.
    [Parameter()]
    [switch] $Pull,

    [Alias("recurse-submodules")]
    [switch] $RecurseSubmodules
)

begin
{
    Set-StrictMode -Version Latest

    $gitFetchCommand = if ($Pull) { 'pull' } else { 'fetch' }

    $svnOpts = @()
    $gitOpts = @('--all')

    if ($RecurseSubmodules)
    {
        $gitOpts += '--recurse-submodules'
    }

    if ($VerbosePreference)
    {
        $svnOpts += '--verbose'
        $gitOpts += '--verbose'
    }

    if ($WhatIfPreference)
    {
        $svnOpts += '--dry-run'
        $gitOpts += '--dry-run'
    }
}

process
{
    $pathParams = @{}

    switch ($PSCmdlet.ParameterSetName)
    {
        'LiteralPath' { $pathParams.LiteralPath = $LiteralPath }
        default { $pathParams.Path = $Path }
    }

    $Command = {
        $item = $_
        switch ($item.Type)
        {
            'svn'
            {
                if ($PSCmdlet.ShouldProcess($item.Path, "svn update"))
                {
                    Write-Debug "svn ${svnOpts} update"
                    & svn $svnOpts update
                }
            }
            'git'
            {
                Write-Debug "[pwd=$($item.Path)] git ${gitFetchCommand} ${gitOpts}"
                git $gitFetchCommand $gitOpts
            }
            default
            {
                Write-Error -Category NotImplemented -Message "For type: ${_}"
            }
        }
    }

    Find-Repositories.ps1 @pathParams -Command $Command -Depth $Depth
}
