using namespace System.Collections.Generic
using namespace System.Diagnostics.CodeAnalysis
using namespace System.Management.Automation

Set-StrictMode -Version Latest

function Write-Progress
{
    [CmdletBinding()]
    [SuppressMessage('PSAvoidOverwritingBuiltInCmdlets', '', Justification = "Maybe if they **worked**")]
    param
    (
        [Parameter(Position = 0, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Activity,

        [Parameter(Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string] $Status = 'Processing',

        [Parameter()]
        [switch] $Completed,

        [Parameter(Position = 2)]
        [int] $Id = -1,

        [Parameter()]
        [int] $ParentId = -1,

        [Parameter()]
        [int] $PercentComplete = -1,

        [Parameter()]
        [string] $CurrentOperation
    )

    $splat = @{
        Activity = $Activity
        Status = $Status
    }

    if ($CurrentOperation)
    {
        $splat.CurrentOperation = $CurrentOperation
    }

    if ($Id -ge 0)
    {
        $Splat.Id = $Id
        $Splat.ParentId = $ParentId
    }

    # BUGBUG: pwsh 7.2.1 Write-Progress -PercentComplete 0 shows PercentComplete=100. so we have to set it to min of 1.
    $splat.PercentComplete = if ($PercentComplete -eq 0) { 1 } else { $PercentComplete }

    if ($Completed)
    {
        # MSCRAP: To show 100% complete you have to sleep for a fraction of a second after setting the bar to 100%,
        # then call Write-Progress *again* with -Completed.
        Microsoft.PowerShell.Utility\Write-Progress @splat -PercentComplete 100
        Start-Sleep -Milliseconds 1
        Microsoft.PowerShell.Utility\Write-Progress @splat -Completed
    }
    else
    {
        Microsoft.PowerShell.Utility\Write-Progress @splat
    }

    # Because the progress bar seems wonky, do an immediate short sleep.
    Start-Sleep -Milliseconds 1
}

<#
.SYNOPSIS
Writes an information header.
#>
function Write-Header
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position = 0, Mandatory)]
        [object] $Object
    )

    # NOTE: we don't have new-text.  Write ANSI directly
    [string] $str = "${Object}"

    Write-Host "`e[97m${str}`e[0;0m"
    Write-Host '=' * $str.Length
    Write-Host ''
}

function Enter-Operation
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position = 0, Mandatory)]
        [string] $Name
    )

    Write-Information -Tags $OperationTag, $EnterTag -MessageData "${Name}`u{2026}"
}

$OperationTag = 'bootstrap.ux:operation'
$EnterTag = 'bootstrap.ux:enter'
$OkTag = 'bootstrap.ux:ok'
$SkipTag = 'bootstrap.ux:skip'
$FailedTag = 'bootstrap.ux:failed'
$ExitTag = 'bootstrap.ux:exit'

class SkipException : Exception
{
    SkipException() : base() {}
    SkipException([string] $Message) : base($Message) {}
}

function Skip-Operation
{
    [CmdletBinding()]
    [OutputType([void])]
    param([object] $MessageData)

    throw [SkipException]::new($MessageData)
}

function Invoke-Operation
{
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        [Parameter(Position = 0, Mandatory)]
        [string] $Name,

        [Parameter(Position = 1, Mandatory)]
        [scriptblock] $ScriptBlock,

        [Parameter(ValueFromRemainingArguments)]
        [object[]] $ArgumentList
    )

    begin
    {
        # Clear out the exit code.
        $LASTEXITCODE = $null
        Enter-Operation -Name:$Name
    }

    process
    {
        if (!$PSCmdlet.ShouldProcess($Name))
        {
            Exit-Operation -Skip -InputObject 'WhatIf'
            return
        }

        try
        {
            Invoke-Command -ScriptBlock:$ScriptBlock -ArgumentList:$ArgumentList
            $success = $?

            if ($null -ne $LASTEXITCODE)
            {
                Exit-Operation -LastExitCode:$LASTEXITCODE
            }
            elseif ($success)
            {
                Exit-Operation
            }
            else
            {
                throw "Unknown or unspecified error"
            }
        }
        catch [SkipException]
        {
            Exit-Operation -Skip $_
            return
        }
        catch
        {
            Exit-Operation $_
            return
        }
    }
}

enum Result
{
    Ok
    Skip
    Failed
}

#
# Constants
#

$okResult = '[{0}  OK  {1}]' -f "`e[32;1m", $PSStyle.Reset
$skipResult = '[{0} SKIP {1}]' -f $PSStyle.Formatting.Warning, $PSStyle.Reset
$failedResult = "[`e[31mFAILED`e[0m]" -f $PSStyle.Formatting.Error, $PSStyle.Reset

$resultPrefix = $PSStyle.Formatting.FeedbackAction + ('-' * 10) + '> ' + $PSStyle.Reset
$failedEmptyMessage = $resultPrefix + $failedResult

#
# Results
#
function Result
{
    [OutputType([string])]
    param([string] $result, [object] $message, [string[]] $tags)

    $messageData = if ($message)
    {
        '{0}{1} ({2})' -f $resultPrefix, $result, ($message | Out-String -NoNewline)
    }
    else
    {
        '{0}{1}' -f $resultPrefix, $result
    }

    Write-Information -Tags (@($OperationTag, $ExitTag) + $tags) -MessageData:$MessageData
}

$separator = '-' * 80

function Ok([object] $message = $null)
{
    return Result $okResult $message -tags $OkTag
}

function Skip([object] $message = $null)
{
    return Result $skipResult $message -tags $SkipTag
}

function Fail([object] $message = $null)
{
    Result $failedResult $message -Tags $FailedTag
    if ($message -is [ErrorRecord] -or $message -is [IEnumerable[ErrorRecord]])
    {
        $message | Format-List * -Force
    }
}

function Test-Skip([object] $InputObject)
{
    $InputObject -is [InformationRecord] -and $InputObject.Tags -ccontains $SkipTag
}

function Exit-Operation
{
    [CmdletBinding(DefaultParameterSetName = 'Object')]
    [OutputType([string])]
    param
    (
        [Parameter(Position = 0, ParameterSetName = 'Object')]
        [object] $InputObject,

        # Explicit skip
        [Parameter(ParameterSetName = 'Object')]
        [switch] $Skip,

        # Explicit failure
        [Parameter(ParameterSetName = 'Object')]
        [switch] $Fail,

        [Parameter(Mandatory, ParameterSetName = 'LastExitCode')]
        $LastExitCode
    )

    process
    {
        switch ($PSCmdlet.ParameterSetName)
        {
            'Object'
            {
                if ($Fail)
                {
                    # Manual fail.
                    return Fail $InputObject
                }
                if ($Skip)
                {
                    # Manual skip.
                    return Skip $InputObject
                }

                if ($null -eq $InputObject -or $InputObject -eq '' -or $InputObject -eq @())
                {
                    return Ok
                }

                if ($errors = $InputObject | Where-Object { $_ -is [ErrorRecord] })
                {
                    return Fail $errors
                }

                if (Test-Skip $InputObject)
                {
                    return Skip $InputObject.MessageData
                }

                return Ok $InputObject
            }

            'LastExitCode'
            {
                Write-Warning "Exit-Operation: is last exit code ${LastExitCode}"
                switch ($LastExitCode)
                {
                    0 { return Ok }
                    { $_ -gt 0 -and $_ -lt 65535 }
                    {
                        return Failed ("Exited with code {0}" -f $LastExitCode)
                    }
                    default
                    {
                        return Failed ("Exited with code 0x{0:X8}" -f $LastExitCode)
                    }
                }
            }

            default
            {
                Write-Error -Category InvalidArgument -Message "Unsupported parameter set: '${_}'"
                return
            }
        }
    }
}

