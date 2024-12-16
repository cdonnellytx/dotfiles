using namespace System
using namespace System.IO
using namespace System.Runtime.InteropServices

<#
.SYNOPSIS
    SSH Agent support
#>
param()

Set-StrictMode -Version Latest

# Only add to interactive environments.
# @see https://stackoverflow.com/questions/9738535/powershell-test-for-noninteractive-mode
if (![Environment]::UserInteractive -or [Console]::IsOutputRedirected)
{
    Write-Verbose "Environment not user interactive; will not load."
    return
}

Write-Verbose "ENTRY"

function Import-SshAgent
{
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [Hashtable] $ssh,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]] $environment
    )

    # you can't do . <file> inside one of these scripts.
    # That and it's a UNIX dot file, so extract name/value and do it manually.
    # CYGCRAP: Cygwin 1.7 lumps it all on one line.
    Write-Verbose "Importing SSH agent:`n$($ssh | Out-String)"

    $environment |
        Select-String -Pattern '(?:^|;\s*)(?<Name>SSH_\w+)=(?<Value>[^;#]*)' -AllMatches |
        ForEach-Object { $_.Matches } |
        ForEach-Object {
            [Environment]::SetEnvironmentVariable($_.Groups["Name"], $_.Groups["Value"])
            Write-Verbose "Set Env:$($_.Groups["Name"]) = '$($_.Groups["Value"])'"
        }
}

####################################################################################################################################
# Main
####################################################################################################################################

[Hashtable] $ssh = @{}


# Required environment variables.
if (!$Env:HOME) { throw "Env:HOME not set." }
if (!$Env:NAME) { throw "Env:NAME not set." }

# Agent type: determined by whether this is Windows 10 1803 or later.
# Of course the way to tell is different in Core vs. Desktop.
Write-Verbose "Determining agent type"
$ssh.AgentType = 'eval' # ASSUMPTION: default to "eval"
if ($IsWindows)
{
    [Version] $winver = $null
    if ($PSVersionTable.ContainsKey("BuildVersion"))
    {
        $winver = $PSVersionTable.BuildVersion
    }
    elseif ($PSVersionTable.ContainsKey("OS"))
    {
        # OS on Core for Windows is "Microsoft Windows 10.0.17134" or similar.
        if ($PSVersionTable.OS -imatch 'microsoft windows (\d+(?:\.\d+)+)')
        {
            $winver = [Version]$Matches[1]
        }
        else
        {
            throw "$($PSVersionTable.OS) does not match expected pattern of 'Microsoft Windows x.y.z'."
        }
    }
    else
    {
        throw "Cannot determine operating system version for Windows.  No expected `$PSVersionTable keys were found."
    }

    if ($winver -ge [Version]"10.0.17134")
    {
        # This is the new Win32 OpenSSH available on Windows 10 10.0.17134.48 (1803) and later.
        # ssh-agent is special here because it runs a single instance as SYSTEM, and does not output any text.
        $ssh.AgentType = 'silent'
    }
}

$ssh.Home        = Join-Path $Env:HOME '.ssh'
$ssh.Commands    = @{
    # MSCRAP: it's faster to not specify a type than to specify -Type Application.  Go figure.
    # MSCRAP: if we're in Windows 10 and in Visual Studio, we can't pick this up, because ssh-agent
    Ssh     = Get-Command -Name 'ssh'       -ErrorAction Ignore
    Agent   = Get-Command -Name 'ssh-agent' -ErrorAction Ignore
    Add     = Get-Command -Name 'ssh-add'   -ErrorAction Ignore
}

if ($VerbosePreference)
{
    Write-Verbose "$( $ssh | ConvertTo-Json -Depth 3 | Out-String)"
}


try
{
    $fullName = [IO.Path]::Combine($PSScriptRoot, 'Implementations', "$($ssh.AgentType).ps1")
    . $fullName
}
catch
{
    Write-Error "ERR $_"
    $count = 0
    $errors = for ($ex = $_.Exception; $ex; $ex = $ex.InnerException)
    {
        if ($count++ -gt 0) { "`n -----> " + $ex.ErrorRecord } else { $ex.ErrorRecord }
        "Stack trace:"
        $ex.ErrorRecord.ScriptStackTrace
    }
    Write-Error "Cannot process script for agent type '$($ssh.AgentType)':`n${errors}"
}

Initialize-SshAgent -ssh:$ssh
