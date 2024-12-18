#requires -Version 5.1
using namespace System
using namespace System.Collections.Generic
using namespace System.Diagnostics.CodeAnalysis
using namespace System.IO
using namespace System.Management.Automation
using namespace System.Text
using namespace PoshStopwatch

param
(
)

Set-StrictMode -Version Latest

$debugStopwatch = [StopwatchTree]::new('Debug')

<#
.SYNOPSIS
Creates a new stopwatch.

.NOTES
The stopwatch is not running unless `Start` is specified.

.NOTES
Generally you will want to run these in a script and nest the calls, then run Write-Stopwatch at the end.
#>
function New-Stopwatch
{
    [CmdletBinding()]
    [OutputType([PoshStopwatch.StopwatchTree])]
    [SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    param
    (
        # A name describing the operating being timed.  Required.
        [Parameter(Position = 0, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        # If specified, will start the stopwatch.
        [Parameter()]
        [switch] $Start
    )

    $ii = $debugStopwatch.GetOrAdd($MyInvocation.MyCommand.Name)
    $ii.Start()
    try
    {
        if ($Start)
        {
            return [PoshStopwatch.StopwatchTree]::StartNew($Name)
        }
        else
        {
            return [PoshStopwatch.StopwatchTree]::new($Name)
        }
    }
    finally
    {
        $ii.Stop()
    }
}
<#
.SYNOPSIS
Overrides built-in Measure-Command.
#>
function Invoke-CommandWithStopwatch
{
    [CmdletBinding()]
    [OutputType([void], [PoshStopwatch.StopwatchTree])]
    param
    (
        # The name describing the operating being timed.
        [Parameter(Position = 0, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        # Specifies the expression that is being timed. Enclose the expression in braces (`{}`).
        [Parameter(Position = 1, Mandatory)]
        [Alias("Command")]
        [ScriptBlock] $Expression,

        # Objects bound to the InputObject parameter are optional input for the script block passed to the Expression parameter.
        # Inside the script block, `$_` can be used to reference the current object in the pipeline.
        [PSObject] $InputObject,

        # Passes an object representing the stopwatch to the pipeline. By default, this cmdlet does not generate any output.
        [switch] $PassThru
    )

    $ii = $debugStopwatch.GetOrAdd($MyInvocation.MyCommand.Name)
    $ii.Start()
    $before = $ii.GetOrAdd('Before')
    $after = $ii.GetOrAdd('After')
    $before.Start()
    try
    {
        # Measure-Command cannot capture the time if an exception occurs, so we have to use a stopwatch, and discard Measure-Command's output.
        # But Invoke-Command doesn't invoke in the current context, only a child one... ugh.
        PushStopwatchByName $Name
        try
        {
            $before.Stop()
            [void] (Microsoft.PowerShell.Utility\Measure-Command -Expression:$Expression -InputObject:$InputObject)
            $after.Start()
        }
        catch
        {
            $after.Start()
            $sw.ErrorRecord = $_
            throw $_;
        }
        finally
        {
            $after.Start()
            PopStopwatch -PassThru:$PassThru
        }
    }
    finally
    {
        $after.Stop()
        $ii.Stop()
    }
}

<#
.SYNOPSIS
Creates and starts a new stopwatch.
#>
function Start-Stopwatch
{
    [CmdletBinding()]
    [OutputType([void], [PoshStopwatch.StopwatchTree])]
    [SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    param
    (
        # A name describing the operating being timed.  Required.
        [Parameter(Position = 0, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        # Passes an object representing the stopwatch to the pipeline. By default, this cmdlet does not generate any output.
        [switch] $PassThru
    )

    $ii = $debugStopwatch.GetOrAdd($MyInvocation.MyCommand.Name)
    $ii.Start()
    try
    {
        $sw = [PoshStopwatch.StopwatchTree]::StartNew($Name)
        if ($PassThru)
        {
            return $sw
        }
    }
    finally
    {
        $ii.Stop()
    }
}

<#
.SYNOPSIS
Stops a stopwatch.
#>
function Stop-Stopwatch
{
    [CmdletBinding()]
    [OutputType([void], [PoshStopwatch.StopwatchTree])]
    [SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
    param
    (
        # The stopwatch to stop.  Required.
        [Parameter(Position = 0, Mandatory)]
        [PoshStopwatch.StopwatchTree] $Stopwatch,

        # Passes an object representing the stopwatch to the pipeline. By default, this cmdlet does not generate any output.
        [switch] $PassThru
    )

    $ii = $debugStopwatch.GetOrAdd($MyInvocation.MyCommand.Name)
    $ii.Start()
    try
    {
        $Stopwatch.Stop()
        if ($PassThru)
        {
            return $Stopwatch
        }
    }
    finally
    {
        $ii.Stop()
    }
}

[PoshStopwatch.StopwatchTree] $Script:CurrentStopwatch = $null

<#
.SYNOPSIS
Gets the Stopwatch currently in context, if any.

.EXAMPLE
$t = Get-CurrentStopwatch

.NOTES
Generally not usable outside of a script.
#>
function Get-CurrentStopwatch
{
    [OutputType([PoshStopwatch.StopwatchTree])]
    param()

    $ii = $debugStopwatch.GetOrAdd($MyInvocation.MyCommand.Name)
    $ii.Start()
    try
    {
        return $Script:CurrentStopwatch
    }
    finally
    {
        $ii.Stop()
    }
}

<#
.SYNOPSIS
Adds elapsed time under the current stopwatch.
.NOTES
For externally run timings.
#>
function Add-Elapsed
{
    [CmdletBinding()]
    [OutputType([void])]
    param
    (
        # A name describing the operating being timed.  Required.
        [Parameter(Position = 0, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        # The elapsed time.
        [Parameter(Position = 1, Mandatory)]
        [ValidateNotNull()]
        [timespan] $Elapsed
    )

    $ii = $debugStopwatch.GetOrAdd($MyInvocation.MyCommand.Name)
    $ii.Start()
    try
    {
        if (!$Script:CurrentStopwatch)
        {
            Write-Error -Category InvalidOperation -Message "No current stopwatch found."
        }

        $child = $Script:CurrentStopwatch.GetOrAdd($Name);
        $child.Add($Elapsed)
    }
    finally
    {
        $ii.Stop()
    }
}

function PushStopwatchByName([string] $Name)
{
    $ii = $debugStopwatch.GetOrAdd('PushStopwatchByName')
    $ii.Start()
    try
    {
        $Script:CurrentStopwatch = if ($Script:CurrentStopwatch)
        {
            $Script:CurrentStopwatch.GetOrAdd($Name)
        }
        else
        {
            [PoshStopwatch.StopwatchTree]::new($Name)
        }

        $Script:CurrentStopwatch.Start()
    }
    finally
    {
        $ii.Stop()
    }
}

function PushStopwatchByObject([StopwatchTree] $Stopwatch)
{
    $ii = $debugStopwatch.GetOrAdd('PushStopwatchByObject')
    $ii.Start()
    try
    {
        $Script:CurrentStopwatch = $Stopwatch
        $Script:CurrentStopwatch.Start()
    }
    finally
    {
        $ii.Stop()
    }
}


<#
.SYNOPSIS
Pushes the stopwatch onto a stack.
#>
function Push-Stopwatch
{
    [CmdletBinding(DefaultParameterSetName = 'Name')]
    [OutputType([void], [PoshStopwatch.StopwatchTree])]
    param
    (
        # A name describing the operating being timed.  Required.
        [Parameter(ParameterSetName = 'Name', Position = 0, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        # The stopwatch to push.
        [Parameter(ParameterSetName = 'Stopwatch', Position = 0, Mandatory)]
        [ValidateNotNull()]
        [PoshStopwatch.StopwatchTree] $Stopwatch,

        # Passes an object representing the stopwatch to the pipeline. By default, this cmdlet does not generate any output.
        [switch] $PassThru
    )

    $ii = $debugStopwatch.GetOrAdd($MyInvocation.MyCommand.Name)
    $ii.Start()
    try
    {
        switch ($PSCmdlet.ParameterSetName)
        {
            'Name' { PushStopwatchByName $Name }
            'Stopwatch' { PushStopwatchByObject $Stopwatch }
            default { Write-Error -Category NotImplemented -Message "For parameter set '${_}'" }
        }

        if ($PassThru)
        {
            return $Script:CurrentStopwatch
        }
    }
    finally
    {
        $ii.Stop()
    }
}

function PopStopwatch()
{
    $ii = $debugStopwatch.GetOrAdd('PopStopwatch')
    $ii.Start()
    try
    {
        if ($Stopwatch = $Script:CurrentStopwatch)
        {
            $Script:CurrentStopwatch = $Stopwatch.Parent
            $Stopwatch.Stop()
            return $Stopwatch
        }
    }
    finally
    {
        $ii.Stop()
    }
}

<#
.SYNOPSIS
Pops the stopwatch off the stack.
#>
function Pop-Stopwatch
{
    [CmdletBinding()]
    [OutputType([void], [PoshStopwatch.StopwatchTree])]
    param
    (
        # Passes an object representing the stopwatch to the pipeline. By default, this cmdlet does not generate any output.
        [switch] $PassThru
    )

    $ii = $debugStopwatch.GetOrAdd($MyInvocation.MyCommand.Name)
    $ii.Start()
    try
    {
        $stopwatch = PopStopwatch

        if ($PassThru)
        {
            return $stopwatch
        }
    }
    finally
    {
        $ii.Stop()
    }
}

<#
.SYNOPSIS
Clears the stopwatch stack.
#>
function Clear-Stopwatch
{
    [CmdletBinding()]
    [OutputType([void])]
    param()

    $ii = $debugStopwatch.GetOrAdd($MyInvocation.MyCommand.Name)
    $ii.Start()
    try
    {
        if ($DebugPreference) { Write-Debug "CLEAR" }
        $Script:CurrentStopwatch = $null
    }
    finally
    {
        $ii.Stop()
    }
}

#
# Output
#

class TimingInformationOptions
{
    [timespan] $ErrorThreshold = [TimeSpan]::MaxValue
    [timespan] $WarningThreshold = [TimeSpan]::MaxValue
    [string[]] $Tags = 'stopwatch'
    [int] $MaxDepth
}

class Indent
{
    static [Dictionary[uint32, string]] $Cache = [Dictionary[uint32, string]]::new()

    static [string] Get([uint32] $Depth)
    {
        [string] $result = $null
        if (![Indent]::Cache.TryGetValue($Depth, [ref] $result))
        {
            $result = switch ($Depth)
            {
                0 { '' }
                default { '  ' * $Depth + '|--' }
            }

            [Indent]::Cache.Add($Depth, $result)
        }

        return $result
    }
}

class TimingInformationMessage : HostInformationMessage
{
    [PoshStopwatch.StopwatchTree] $Stopwatch
    [uint32] $Depth

    TimingInformationMessage([PoshStopwatch.StopwatchTree] $Stopwatch, [uint32] $Depth, [TimingInformationOptions] $Options = [TimingInformationOptions]::new())
    {
        $this.Depth = $Depth
        $this.Stopwatch = $Stopwatch

        $this.Message = ("{0}{1} - {2}" -f [Indent]::Get($depth), $Stopwatch.Elapsed, $Stopwatch.Name)

        $palette = if ($null -ne $Stopwatch.ErrorRecord)
        {
            # PowerShell 7+: use error accent color
            if ($global:PSVersionTable.Version -ge 7) { 'ErrorAccent' } else { 'Error' }
        }
        elseif ($Stopwatch.Elapsed -ge $Options.ErrorThreshold)
        {
            'Error'
        }
        elseif ($Stopwatch.Elapsed -ge $options.WarningThreshold)
        {
            'Warning'
        }
        else
        {
            'Default'
        }

        $this.SetColors($palette)
    }

    hidden [void] SetColors([string] $palette)
    {
        # Try setting colors based on private data.
        $local:host = $global:host

        switch ($palette)
        {
            'ErrorAccent'
            {
                # NOTE: we can assume PowerShell 7+ here, any valid color should work
                $this.BackgroundColor = $host.PrivateData.ErrorBackgroundColor
                $this.ForegroundColor = $host.PrivateData.ErrorAccentColor
            }
            'Error'
            {
                # If we can't set the colors, pick a reasonable default.
                try
                {
                    $this.BackgroundColor = $host.PrivateData.ErrorBackgroundColor
                    $this.ForegroundColor = $host.PrivateData.ErrorForegroundColor
                }
                catch
                {
                    $this.BackgroundColor = $host.UI.RawUI.BackgroundColor
                    $this.ForegroundColor = [ConsoleColor]::Red
                }
            }
            'Warning'
            {
                # If we can't set the colors, pick a reasonable default.
                try
                {
                    $this.BackgroundColor = $host.PrivateData.WarningBackgroundColor
                    $this.ForegroundColor = $host.PrivateData.WarningForegroundColor
                }
                catch
                {
                    $this.BackgroundColor = $host.UI.RawUI.BackgroundColor
                    $this.ForegroundColor = [ConsoleColor]::Yellow
                }
            }

            # Default: no special colors.
        }
    }
}

function SumElapsed([TimeSpan[]] $values)
{
    $result = [TimeSpan]::Zero
    foreach ($value in $values)
    {
        $result += $value
    }
    return $result
}

function WriteStopwatchAndDescendants
{
    [CmdletBinding()]
    param
    (
        # A Stopwatch object.
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [PoshStopwatch.StopwatchTree] $Stopwatch,

        # The options.
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [TimingInformationOptions] $Options,

        # The current depth to print.
        [Parameter(Mandatory)]
        [uint32] $Depth
    )

    $msg = [TimingInformationMessage]::new($Stopwatch, $Depth, $Options)

    Write-Information -MessageData $msg -Tags $Options.Tags -InformationAction Continue

    if ($Depth -eq $Options.MaxDepth)
    {
        # Explicitly do not print children.
        return
    }

    $children = $Stopwatch.Children
    if (!$children)
    {
        return
    }

    $childDepth = $Depth + 1

    foreach ($child in $children)
    {
        WriteStopwatchAndDescendants -Stopwatch:$child -Options:$Options -Depth:$childDepth
    }
}

<#
.SYNOPSIS
Writes the specified Stopwatch object and its descendants to the information log.

.EXAMPLE

Example 1: Time a command inline

PS C:\>$timing = Invoke-Stopwatch -Name Example1 -Command { ... }
PS C:\>Write-Stopwatch -Stopwatch $timing

This should print an output similar to the following:
00:00:02.5038262 - Profile
  |--00:00:00.0776554 - Stopwatch
  |--00:00:00.0542514 - RunScript1.ps1
  |--00:00:00.0327283 - RunScript2.ps1
  |--00:00:02.4835488 - RunScript3.ps1
    |--00:00:00.0839720 - Foo
    |--00:00:00.1021999 - Bar
      |--00:00:00.0306644 - Child 1
      |--00:00:00.0075099 - Child 2
      |--00:00:00.0640256 - **OTHER**
    |--00:00:00.1197117 - Baz

.NOTES
Generally this should be run near the very end of the script.
#>
function Write-Stopwatch
{
    [CmdletBinding()]
    param
    (
        # A Stopwatch object.
        [Parameter(Position = 0, Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNull()]
        [PoshStopwatch.StopwatchTree] $Stopwatch,

        # Specifies a threshold above which items are considered to be slow enough to be warnings.
        [Parameter()]
        [TimeSpan] $WarningThreshold = [TimeSpan]::MaxValue,

        # Specifies a threshold above which items are considered to be significantly slow and displayed as errors.
        [Parameter()]
        [TimeSpan] $ErrorThreshold = [TimeSpan]::MaxValue,

        # The maximum depth of recursion to print.
        [Parameter()]
        [uint32] $Depth = 100
    )

    begin
    {
        $Options = [TimingInformationOptions] @{
            ErrorThreshold = $ErrorThreshold
            WarningThreshold = $WarningThreshold
            MaxDepth = $Depth
        }
    }

    process
    {
        WriteStopwatchAndDescendants -Stopwatch:$Stopwatch -Options:$Options -Depth:0
    }
}

function Get-DebugStopwatch
{
    return $debugStopwatch
}

function Measure-TimeSpan
{
    [CmdletBinding()]
    param
    (
        [Parameter(ValueFromPipeline)]
        [TimeSpan] $InputObject
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

        [List[long]] $buffer = [List[long]]::new()
    }

    process
    {
        $buffer.Add($InputObject.Ticks)
    }

    end
    {
        $buffer | Microsoft.PowerShell.Utility\Measure-Object -AllStats | Format-WithTimeSpan
    }
}