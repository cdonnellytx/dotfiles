#requires -version 7 -modules Microsoft.PowerShell.Utility

using namespace System.Collections.Generic
using namespace System.Diagnostics.CodeAnalysis

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

    $padding = $host.UI.RawUI.WindowSize.Width -ge 110 ? 100 : 60

    Write-Host -NoNewline ("${Name}`u{2026}".PadRight($padding))
}

$okResult     = "[  `e[32mOK`e[0m  ]"
$failedResult = "[`e[31mFAILED`e[0m]"

function Exit-Operation
{
    [CmdletBinding(DefaultParameterSetName = 'OK')]
    param
    (
        [Parameter(Position = 0, ParameterSetName = 'Object')]
        $InputObject,

        [Parameter(Mandatory, ParameterSetName = 'Error', ValueFromPipeline)]
        [Alias('Error')]
        $Err,

        [Parameter(Mandatory, ParameterSetName = 'LastExitCode')]
        $LastExitCode
    )

    process
    {
        $msg = switch ($PSCmdlet.ParameterSetName)
        {
            'OK' { $okResult }
            'Object'
            {
                '{0} ({1})' -f $okResult, (Out-String -InputObject $InputObject -NoNewline)
            }
            'Error'
            {
                if ($Err)
                {
                    Write-Error $Err
                    return $failedResult
                }
                else
                {
                    return $okResult
                }
            }
            'LastExitCode'
            {
                switch ($LastExitCode)
                {
                    0 { return $okResult }
                    default { return $failedResult }
                }
            }
        }

        Write-Output $msg
    }
}

