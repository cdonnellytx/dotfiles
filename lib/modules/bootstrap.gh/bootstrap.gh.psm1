#requires -version 7.0
#requires -modules bootstrap.logging

$gh = Get-Command -ErrorAction Stop -CommandType Application -Name 'gh'

<#
.SYNOPSIS
Wraps gh.exe so we can more easily debug things.
#>
function gh
{
    [CmdletBinding()]
    [OutputType([string[]])]
    param
    (
        [Parameter(Position = 0, ValueFromRemainingArguments)]
        [string[]] $Arguments
    )

    if ($DebugPreference)
    {
        Write-Debug "gh.exe ${Arguments}"
    }

    $output = & $gh $Arguments 2>&1
    $success = $?

    if ($DebugPreference)
    {
        Write-Debug "Success: ${success}"
    }

    Write-BootstrapLog -Debug:$DebugPreference @{
        Command = @($gh | Out-String) + $Arguments
        Success = $success
        Output = $output
        Messages = $messages
    }

    Write-Debug "output judgment"
    if (!$success)
    {
        Write-Error -Category InvalidArgument -Message ($output | Out-String)
        return
    }

    return [string[]] $output
}

filter IdentityFilter
{
    return $_
}

## gh release view

function Invoke-GHReleaseView
{
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param
    (
        # The repository name and optional org.
        [Parameter(Position = 0, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Repository,

        # The ooptional release
        [Parameter(Position = 10, Mandatory)]
        [string] $TagName,

        [Parameter()]
        [string[]] $Field = $defaultReleaseFields
    )

    gh release view '--repo' $Repository '--json' ($Field -join ',')  $TagName | ConvertFrom-Json
}

$defaultReleaseFields = @('name', 'tagName', 'publishedAt')

filter ReleaseViewFilter([string] $Repository, [string[]] $Field)
{
    Invoke-GHReleaseView -Repository $Repository -TagName $_.tagName -Field $Field
}

<#
.SYNOPSIS
Gets GitHub releases.
#>
function Get-GitHubRelease
{
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param
    (
        # The repository name and optional org.
        [Parameter(Position = 0, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Repository,

        # The ooptional release
        [Parameter(Position = 1)]
        [string] $TagName,

        [Parameter()]
        [Alias('First')]
        [int] $Limit = 30,

        [switch] $IncludeDraft,
        [switch] $IncludePreRelease,

        [Parameter()]
        [string[]] $Field = $defaultReleaseFields
    )

    if ($TagName)
    {
        return Invoke-GHReleaseView -Repository $Repository -TagName $TagName -Field $Field
    }

    [string] $filter = if ($Field | Where-Object { $_ -notin $defaultReleaseFields })
    {
        'ReleaseViewFilter'
    }
    else
    {
        'IdentityFilter'
    }

    [string[]] $Arguments = @()
    if (!$IncludeDraft)
    {
        $Arguments += '--exclude-drafts'
    }
    if (!$IncludePreRelease)
    {
        $Arguments += '--exclude-pre-releases'
    }

    # LATER: Rewrite to use JSON once https://github.com/cli/cli/issues/4572 is implemented.
    gh release list --limit $Limit --repo $Repository @Arguments |
        ConvertFrom-Csv -Delimiter "`t" -Header 'name', 'type', 'tagName', 'publishedAt' |
            Select-Object 'name', 'tagName', 'publishedAt' |
            & $filter -Repository:$Repository -Field:$Field

}
