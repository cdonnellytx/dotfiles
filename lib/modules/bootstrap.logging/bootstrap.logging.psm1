Set-StrictMode -Version Latest

class LogInfo
{
    [void] WriteObject([string] $Message)
    {
        throw [System.NotImplementedException]::new()
    }
}

class DefaultLogInfo : LogInfo
{
    [void] WriteObject([string] $Message)
    {
        Write-Verbose -Message:$Message
    }
}

class FileLogInfo : LogInfo
{
    [string] $Path

    [void] WriteObject([string] $Message)
    {
        Add-Content -LiteralPath $this.Path -Value $Message
    }
}

[LogInfo] $script:Log = [DefaultLogInfo]::new()

<#
.SYNOPSIS
Starts the new bootstrap log.
#>
function New-BootstrapLog
{
    [OutputType([void])]
    param
    (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $LogFile = (Join-Path -Path:(Get-BootstrapTempDirectory) -ChildPath:('bootstrap-windows-{0:yyyy-MM-dd-HH-mm-ss.fff}.log' -f [DateTime]::UtcNow)),
        [switch] $PassThru
    )

    $script:log = [FileLogInfo] @{
        Path = $LogFile
    }

    if ($PassThru)
    {
        return $script:Log
    }
}

function Write-BootstrapLog
{
    [CmdletBinding()]
    [OutputType([void])]
    param
    (
        [Parameter(Position = 0, Mandatory)]
        [object] $InputObject,

        [Parameter()]
        [ValidateNotNull()]
        [LogInfo] $Log = $script:Log
    )

    if ($null -eq $script:Log)
    {
        Write-Error "Log not initialized"
        return
    }

    [string[]] $Content = switch ($InputObject)
    {
        { $_ -is [string] } { $_ }
        { $_ -is [int] } { $_ }
        { $_ -is [long] } { $_ }
        { $_ -is [guid] } { $_ }
        { $_ -is [string[]] } { $_ }
        { $_ -is [bool] } { $_ }
        default
        {
            $_ | ConvertTo-Json -Depth 2 -WarningAction Ignore
        }
    }

    $Message = "[{0:yyyy-MM-dd HH:mm:ss.fff}] {1}" -f [DateTime]::UtcNow, ($Content -join [System.Environment]::NewLine)

    $Log.WriteObject($Message)
    if ($DebugPreference)
    {
        Write-Debug ($Message | Out-String)
    }
}

