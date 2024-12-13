#requires -version 7.0
#requires -modules Microsoft.PowerShell.Utility

Set-StrictMode -Version Latest

<#
.SYNOPSIS
Calculates the aggregate properties of timespans.

.NOTES
MSCRAP: Measure-Object does not support timespans (and still not as of 7.4), and doesn't appear like they will.

.LINK
https://github.com/PowerShell/PowerShell/issues/10712
#>
function Measure-TimeSpan
{
    [CmdletBinding(DefaultParameterSetName = 'GenericMeasure', HelpUri = 'https://go.microsoft.com/fwlink/?LinkID=2096617', RemotingCapability = 'None')]
    [OutputType([PSObject])]
    param
    (
        [Parameter(ValueFromPipeline)]
        [PSObject] $InputObject,

        # Indicates that the cmdlet displays all the statistics of the specified properties.
        [Parameter(ParameterSetName = 'GenericMeasure')]
        [switch] $AllStats,

        # Indicates that the cmdlet displays the sum of the values of the specified properties.
        [Parameter(ParameterSetName = 'GenericMeasure')]
        [switch] $Sum,

        # Indicates that the cmdlet displays the average value of the specified properties.
        [Parameter(ParameterSetName = 'GenericMeasure')]
        [switch] $Average,

        [Parameter(ParameterSetName = 'GenericMeasure')]
        [switch] $StandardDeviation,

        [Parameter(ParameterSetName = 'GenericMeasure')]
        [switch] $Maximum,

        [Parameter(ParameterSetName = 'GenericMeasure')]
        [switch] $Minimum
    )

    begin
    {
        filter Format-WithTimeSpan
        {
            $_ | Select-Object -Property Count,
            @{ Name = 'Average'; Expression = { if ($null -ne $_.Average) { [timespan]::FromTicks($_.Average) } } },
            @{ Name = 'Sum'; Expression = { if ($null -ne $_.Sum) { [timespan]::FromTicks($_.Sum) } } },
            @{ Name = 'Maximum'; Expression = { if ($null -ne $_.Maximum) { [timespan]::FromTicks($_.Maximum) } } },
            @{ Name = 'Minimum'; Expression = { if ($null -ne $_.Minimum) { [timespan]::FromTicks($_.Minimum) } } },
            @{ Name = 'StandardDeviation'; Expression = { if ($null -ne $_.StandardDeviation) { [timespan]::FromTicks($_.StandardDeviation) } } },
            Property
        }

        try
        {
            $outBuffer = $null
            if ($PSBoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer))
            {
                $PSBoundParameters['OutBuffer'] = 1
            }

            $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Microsoft.PowerShell.Utility\Measure-Object', [System.Management.Automation.CommandTypes]::Cmdlet)
            $scriptCmd = { & $wrappedCmd -Property:Ticks @PSBoundParameters | Format-WithTimeSpan }

            $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
            $steppablePipeline.Begin($PSCmdlet)
        }
        catch
        {
            throw
        }
    }

    process
    {
        try
        {
            $steppablePipeline.Process($_)
        }
        catch
        {
            throw
        }
    }

    end
    {
        try
        {
            $steppablePipeline.End()
        }
        catch
        {
            throw
        }
    }

    clean
    {
        if ($null -ne $steppablePipeline)
        {
            $steppablePipeline.Clean()
        }
    }
    <#

    .ForwardHelpTargetName Microsoft.PowerShell.Utility\Measure-Object
    .ForwardHelpCategory Cmdlet

    #>
}