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
    Write-Host "`e[97m${Object}`e[0;0m"
}

function Enter-Operation
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position = 0, Mandatory)]
        [string] $Name
    )

    $padding = [Math]::Clamp($host.UI.RawUI.WindowSize.Width - 40, 60, 150)

    Write-Host -NoNewline ("${Name}`u{2026}".PadRight($padding))
}

$SkipTag = 'bootstrap.ux:skip'

function Skip-Operation
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [object] $MessageData
    )

    Write-Information -Tags $SkipTag -MessageData $MessageData -InformationAction Ignore -InformationVariable iv
    return $iv
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
        if (!$PSBoundParameters.ContainsKey('ErrorAction'))
        {
            $PSBoundParameters['ErrorAction'] = [ActionPreference]::Inquire
        }
    }

    process
    {
        # Clear out the exit code.
        $LASTEXITCODE = $null

        Enter-Operation -Name:$Name
        if (!$PSCmdlet.ShouldProcess($Name))
        {
            Exit-Operation -Skip -InputObject 'WhatIf'
            return
        }

        try
        {
            $result = Invoke-Command -ScriptBlock:$ScriptBlock -ArgumentList:$ArgumentList 2>&1 6>&1
            $success = $?

            if ($result)
            {
                Exit-Operation $result
            }
            elseif ($null -ne $LASTEXITCODE)
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

$okResult = "[  `e[32mOK`e[0m  ]"
$skipResult = "[ `e[33mSKIP`e[0m ]"
$failedResult = "[`e[31mFAILED`e[0m]"

function Result
{
    [OutputType([string])]
    param([string] $result, [string] $message = $null)

    if ($message)
    {
        return '{0} ({1})' -f $result, ($message | Out-String -NoNewline)
    }
    else
    {
        return $result
    }
}

function Ok([string] $message = $null)
{
    return Result $okResult $message
}

function Skip([string] $message = $null)
{
    return Result $skipResult $message
}

function Failed([string] $message = $null)
{
    return Result $failedResult $message
}

function Exit-Operation
{
    [CmdletBinding(DefaultParameterSetName = 'Object')]
    [OutputType([string])]
    param
    (
        [Parameter(Position = 0, ParameterSetName = 'Object')]
        [object] $InputObject,

        [Parameter(ParameterSetName = 'Object')]
        [switch] $Skip,

        [Parameter(Mandatory, ParameterSetName = 'LastExitCode')]
        $LastExitCode
    )

    process
    {
        switch ($PSCmdlet.ParameterSetName)
        {
            'Object'
            {
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
                    return Failed $errors
                }

                if ($skipRecord = $InputObject | Where-Object { $_ -is [InformationRecord] -and $_.Tags -ccontains $SkipTag })
                {
                    return Skip $skipRecord.MessageData
                }

                return Ok $InputObject
            }

            'LastExitCode'
            {
                Write-Warning "Exit-Operation: is last exit code ${LastExitCode}"
                switch ($LastExitCode)
                {
                    0 { return $okResult }
                    { $_ -gt 0 -and $_ -lt 65535 }
                    {
                        return Result($failedResult, ("Exited with code {0}" -f $LastExitCode))
                    }
                    default
                    {
                        return Result($failedResult, ("Exited with code 0x{0:X8}" -f $LastExitCode))
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

