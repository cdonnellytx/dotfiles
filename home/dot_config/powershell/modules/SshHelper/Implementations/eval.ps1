<#
.SYNOPSIS
    SSH Agent support (eval)
#>
#requires -Version 2
using namespace System.Diagnostics.CodeAnalysis
using namespace System.Runtime.InteropServices

Set-StrictMode -Version Latest

function Lock-SshFile
{
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([bool])]
    param
    (
        [Parameter(Position = 0, Mandatory)]
        [ValidateNotNull()]
        [Hashtable] $ssh
    )

    if (Test-SshLock $ssh)
    {
        # can't lock, file already there
        Write-Verbose "[Eval] $($ssh.Lock): already exists"
        return $false
    }

    # make sure the directory exists
    if (!(Test-Path $ssh.Cache))
    {
        mkdir $ssh.Cache -ErrorAction Stop
    }

    try
    {
        if ($PSCmdlet.ShouldProcess($ssh.Lock, 'Lock SSH File'))
        {
            Set-Content -Value 'PowerShell' -Path $ssh.Lock -ErrorAction Stop
            Write-Verbose "[Eval] $($ssh.Lock): successfully locked."
        }
        return $true
    }
    catch
    {
        # couldn't lock.
        Write-Verbose "[Eval] $($ssh.Lock): failed to lock: $_"
        return $false
    }
}

function Unlock-SshFile
{
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param
    (
        [Parameter(Position = 0, Mandatory)]
        [ValidateNotNull()]
        [Hashtable] $ssh
    )

    if (Test-Path -Path $ssh.Lock)
    {
        if ($PSCmdlet.ShouldProcess($ssh.Lock, 'Unlock SSH File'))
        {
            Remove-Item -Path $ssh.Lock -Force -ErrorAction Stop
        }
        Write-Verbose "[Eval] $($ssh.Lock): Removed."
    }
    else
    {
        Write-Verbose "[Eval] $($ssh.Lock): No lock present."
    }
}

<#
.SYNOPSIS
returns true if the SSH lock is in effect, false otherwise
#>
function Test-SshLock
{
    [CmdletBinding()]
    [OutputType([bool])]
    param
    (
        [Parameter(Position = 0, Mandatory)]
        [ValidateNotNull()]
        [Hashtable] $ssh
    )

    $item = Get-Item -Path $ssh.Lock -ErrorAction Ignore
    if (!$item)
    {
        # OK, it was transient
        return $false
    }

    # The lock exists, but is the file stale (over a minute old)?
    # This happens if we start the process but are interrupted, which seems to happen far too often with ConEmu self-updates.
    $age = [DateTime]::UtcNow - $item.LastWriteTimeUtc
    if ($age -ge [TimeSpan]'00:01:00')
    {
        Write-Verbose "[Eval] Forcibly unlocking expired SSH file ($age)"
        Unlock-SshFile $ssh
        # We are no longer locked.
        return $false
    }

    return $true
}

<#
.SYNOPSIS
Initialize the SSH agent.
 #>
function Initialize-SshAgent
{
    [CmdletBinding()]
    [OutputType([void])]
    [SuppressMessage('PSAvoidGlobalVars', '')]
    param
    (
        [Parameter(Position = 0)]
        [ValidateNotNullOrEmpty()]
        [Hashtable] $ssh = $global:ssh
    )

    if (!(Test-SshAgent))
    {
        if (!(Resolve-SshAgent -ssh $ssh))
        {
            Write-Error "[Eval] Unable to find or start SSH agent"
            return
        }
    }

    Register-DefaultSshKey -ssh $ssh

    # Git: set its SSH to the main executable.
    # Otherwise it will use whichever one it wants... which on Windows typically means "the one that comes with it".
    # (Git for Windows, PortableGit, GitHub Git, or Cygwin ALL do this.)
    if (!$Env:GIT_SSH -or !$Env:RSYNC_RSH)
    {
        $ssh.Main = $ssh.Commands.ssh
        if (!$ssh.Main)
        {
            Write-Verbose "[Eval] ssh not in PATH"
            return
        }

        Write-Verbose "[Eval] setting Env:GIT_SSH and more to $($ssh.Main.Path)"
        $Env:GIT_SSH = $ssh.Main.Path
        $Env:RSYNC_RSH = $ssh.Main.Path
    }
}

# private
function Register-DefaultSshKey
{
    [CmdletBinding()]
    [OutputType([void])]
    param
    (
        [Parameter(Position = 0, Mandatory)]
        [ValidateNotNull()]
        [Hashtable] $ssh
    )

    if (!(Get-ChildItem -LiteralPath $ssh.Home -Filter "id_*sa"))
    {
        # no default keys to add.
        # We succeeded -- vacuously.
        Write-Verbose "[Eval] no keys to add"
        return
    }

    # auto-add .ssh key
    # PSCRAP: Call operator ONLY puts things into $Global:Error here, regardless of what I do.
    # Not even the -q option in Windows 10 (1803) does anything to stop this!!!!!!
    $errorCount = $Error.Count
    $output = & $ssh.Commands.Add 2>&1
    if ($LASTEXITCODE -ne 0)
    {
        # Failure.  Just exit, leave the errors in $Error
        switch -regex ($output)
        {
            '\bcommunication with agent failed\b'
            {
                throw [ExternalException]($output | Out-String)
            }
            default
            {
                Write-Verbose "[Eval] ssh-add returned $LASTEXITCODE`n-------`n${output}"
            }
        }
        return
    }

    # success.
    # output is probably keys added.
    if ($Error.Count -gt $errorCount)
    {
        # Remove the stubborn errors
        $Error.RemoveRange($errorCount, $Error.Count - $errorCount)
    }

    #Write-Host -Object ([string]::Join([Environment]::NewLine, $output))
    Write-Verbose "[Eval] Added keys"
}

<#
.SYNOPSIS
Tests whether the SSH agent is running.
 #>
function Test-SshAgent
{
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!($Env:SSH_AGENT_PID))
    {
        Write-Verbose "[Eval] Test-SshAgent: SSH_AGENT_PID is not set"
        return $false
    }

    if (!($process = Get-Process -Id $Env:SSH_AGENT_PID -ErrorAction Ignore))
    {
        Write-Verbose "[Eval] Test-SshAgent: SSH_AGENT_PID ($Env:SSH_AGENT_PID) is not running or is not accessible"
        return $false
    }

    if ($process.Name -cne 'ssh-agent')
    {
        Write-Verbose "[Eval] Test-SshAgent: SSH_AGENT_PID ($Env:SSH_AGENT_PID) is '$($process.Name)', not 'ssh-agent'"
        return $false
    }

    Write-Verbose "[Eval] Test-SshAgent: SSH_AGENT_PID ($Env:SSH_AGENT_PID) is 'ssh-agent'"
    return $true
}

function Start-SshAgent
{
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([bool])]
    param
    (
        [Parameter(Position = 0, Mandatory)]
        [ValidateNotNull()]
        [Hashtable] $ssh
    )

    if (!(Lock-SshFile $ssh))
    {
        Write-Verbose "[Eval] couldn't lock"
        return $false
    }

    try
    {
        # MSCRAP: if two shells start simultaneously you can get the dreaded "The process cannot access the file 'X' because it is being used by another process."
        # To avoid that, ignore if it
        [string[]] $environment = (& $ssh.Commands.Agent) -Replace '^echo', '#echo'
        if (!$environment)
        {
            Write-Warning "[Eval] ssh-agent returned no text, but is not expected to be silent."
            return $true
        }

        try
        {
            if ($VerbosePreference)
            {
                Write-Verbose "[Eval] WRITING $($ssh.Environment)"
                Write-Verbose $($environment | ForEach-Object { "[Eval] > ${_}"} | Out-String)
            }
            Set-Content -NoNewline -Path $ssh.Environment -Encoding UTF8 -Value ([string]::Join("`n", $environment))
            Write-Verbose "[Eval] WROTE   $($ssh.Environment)"
        }
        catch [Microsoft.PowerShell.Commands.WriteErrorException]
        {
            Write-Verbose "[Eval] Failed to write $($ssh.Environment)"

            # Kill the SSH process if we need to.
            $environment |
                Where-Object { $_ -match '^SSH_AGENT_PID=(\d+)' } |
                ForEach-Object {
                    $SshPid = $Matches[1]
                    Stop-Process -Id $SshPid 2> $null
                    Write-Verbose "[Eval] Process ${SshPid} has been killed"
                }

            return $false
        }

        Write-Verbose "[Eval] ssh-agent started."

        Import-SshAgent -ssh $ssh -environment $environment

        if (!(Test-Path $ssh.Home)) { return $false }

        return $true
    }
    finally
    {
        Unlock-SshFile $ssh
    }
}

function Resolve-SshAgentInternal
{
    [CmdletBinding()]
    [OutputType([bool])]
    param
    (
        [Parameter(Position = 0, Mandatory)]
        [ValidateNotNull()]
        [Hashtable] $ssh
    )

    # The hard way
    if ($sshEnvItem = Get-Item -ErrorAction Ignore -Path $ssh.Environment)
    {
        $environment = Get-Content -Path $sshEnvItem.FullName
        Import-SshAgent -ssh $ssh -environment $environment
        if (Test-SshAgent)
        {
            Write-Verbose "[Eval] Process already found in cache $($ssh.Environment)"
            return $true
        }
        elseif (Start-SshAgent $ssh)
        {
            Write-Verbose "[Eval] Started with cache ($($ssh.Environment))"
            return $true
        }
    }
    elseif (Test-SshLock $ssh)
    {
        Write-Verbose "[Eval] Lock file detected.  Sleeping."
    }
    elseif (Start-SshAgent $ssh)
    {
        Write-Verbose "[Eval] Started without cache ($($ssh.Environment))"
        return $true
    }

    return $false
}

function Resolve-SshAgent
{
    [CmdletBinding()]
    [OutputType([bool])]
    param
    (
        [Parameter(Position = 0, Mandatory)]
        [ValidateNotNull()]
        [Hashtable] $ssh
    )

    # Source SSH settings, if applicable
    # In the event multiple shells start simultaneously, try up to N times
    Write-Verbose "[Eval] resolve agent"
    [int] $maxAttempts = 5
    [int] $attempt = 0
    [bool] $done = $false
    while (!$done)
    {
        $attempt++;

        [bool] $done = $false
        try
        {
            Write-Verbose "[Eval] resolve agent $attempt/$maxAttempts"
            $done = Resolve-SshAgentInternal $ssh
        }
        catch [ExternalException]
        {
            # SSH agent failed
            Write-Error $_
            break
        }

        if ($done)
        {
            break
        }
        elseif ($attempt -ge $maxAttempts)
        {
            throw "[Eval] SSH-Agent attempt $attempt/$maxAttempts failed.  No attempts remaining";
        }
        else
        {
            Write-Verbose "[Eval] Attempt $attempt/$maxAttempts failed; sleeping..."
            Start-Sleep -Milliseconds 100
        }
    }

    if ($IsWindows -and $Env:SSH_AUTH_SOCK -cmatch '^/') # Unix path
    {
        $Env:SSH_AUTH_SOCK = (cygpath -am $Env:SSH_AUTH_SOCK)
    }

    return $done
}


####################################################################################################################################
# Apply additional properties
####################################################################################################################################

$ssh.CacheRoot   = Join-Path $ssh.Home '.cache'
$ssh.Cache       = Join-Path $ssh.CacheRoot $Env:NAME  # MUST be machine-specific
$ssh.Lock        = Join-Path $ssh.Cache 'ssh-environment.lock'
$ssh.Environment = Join-Path $ssh.Cache 'ssh-environment'

