<#
.SYNOPSIS
    SSH Agent (Silent variant)
    Used in Windows 10 build 1803 and later
#>

#requires -Version 5

if (!$IsWindows)
{
    throw [PlatformNotSupportedException] "Not yet implemented"
}

<#
.SYNOPSIS
Initialize the SSH agent.
 #>
function Initialize-SshAgent
{
    [CmdletBinding()]
    [OutputType([void])]
    param
    (
        [Parameter(Position = 0)]
        [ValidateNotNullOrEmpty()]
        [Hashtable] $ssh = $global:ssh
    )

    Write-Verbose "[SshHelper.Silent] ssh-agent is a Windows service and does not need initializing."
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

    if (!($service = Get-Service -Name 'ssh-agent'))
    {
        Write-Verbose "[SshHelper.Silent] Test-SshAgent: ssh-agent service not found"
        return $false
    }

    if ($service.Status -eq 'Running')
    {
        Write-Verbose "[SshHelper.Silent] Test-SshAgent: ssh-agent service is running"
        return $true
    }

    if ($service.StartType -eq 'Disabled')
    {
        Write-Verbose "[SshHelper.Silent] Test-SshAgent: ssh-agent service is disabled"
    }
    else
    {
        Write-Verbose "[SshHelper.Silent] Test-SshAgent: ssh-agent service is not running"
    }
    return $false
}

function Start-SshAgent
{
    [CmdletBinding()]
    [OutputType([bool])]
    param
    (
        [Parameter(Position = 0, Mandatory)]
        [ValidateNotNull()]
        [Hashtable] $ssh
    )

    # Windows: silent SSH agent is a service
    if ($service = Get-Service -Name 'ssh-agent')
    {
        if ($service.Status -eq 'Running')
        {
            throw '[SshHelper.Silent] ssh-agent service already running'
        }
        elseif (Start-Service -InputObject $service)
        {
            Write-Verbose '[SshHelper.Silent] Started ssh-agent service'
        }
        else
        {
            Write-Verbose '[SshHelper.Silent] Failed to start ssh-agent service'
            return $false
        }
    }
    else
    {
        # Not windows, or service didn't start. Run manually.
        & $ssh.Commands.Agent
        if ($LASTEXITCODE -eq 0)
        {
            Write-Verbose '[SshHelper.Silent] Started ssh-agent command'
        }
        else
        {
            Write-Verbose '[SshHelper.Silent] Failed to start ssh-agent'
            return $false
        }
    }

    return $true
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

    # Just turn it on :)
    return (Test-SshAgent) -or (Start-SshAgent $ssh)
}

