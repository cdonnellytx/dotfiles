param([switch] $NoVersionWarn)

$psv = $PSVersionTable.PSVersion

if ($psv.Major -lt 3 -and !$NoVersionWarn) {
    throw ("posh-svn support for PowerShell 2.0 is deprecated; you have version $($psv).`n" +
    "To download version 5.0, please visit https://www.microsoft.com/en-us/download/details.aspx?id=50395`n" +
    "For more information and to discuss this, please visit **TODO PR**`n" +
    "To suppress this warning, change your profile to include 'Import-Module posh-svn -Args `$true'.")
}


[string[]] $Scripts = @('CheckVersion', 'SvnUtils', 'SvnPrompt', 'SvnTabExpansion') | ForEach-Object {
    Join-Path $PSScriptRoot "${_}.ps1"
}

if ($poshGit = Get-Module -Name posh-git -ErrorAction Ignore)
{
    $PoshGitRoot = (Get-Item $poshGit.Path).Directory.FullName

    $Scripts += @(
        "AnsiUtils.ps1",
        "PoshGitTypes.ps1"
    )| ForEach-Object {
        Join-Path $PoshGitRoot $_
    }
}

$Scripts | ForEach-Object {
    $fullName = $_
    try {
        . $fullName
    }
    catch {
        $count = 0
        $errors = for ($ex = $_.Exception; $ex; $ex = $ex.InnerException) {
            if ($count++ -gt 0) { "`n -----> " + $ex.ErrorRecord } else { $ex.ErrorRecord }
            "Stack trace:"
            $ex.ErrorRecord.ScriptStackTrace
        }
        Write-Error "Cannot process script '${fullName}':`n${errors}"
    }
}

Export-ModuleMember -Function @(
    'Write-SvnStatus',
    'Get-SvnStatus',
    'Get-SvnInfo',
    'TabExpansion',
    'tsvn',
    'Invoke-Svn'
) -Alias @(
    'svn'
)
