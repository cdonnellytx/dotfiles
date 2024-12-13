<#
.SYNOPSIS
    Optimizes your PSReadline history save file.
.DESCRIPTION
    Optimizes your PSReadline history save file by removing duplicate
    entries and optionally removing commands that are not longer than
    a minimum length
.EXAMPLE
    C:\PS> Optimize-PSReadlineHistory
    Removes all the duplicate commands.
.EXAMPLE
    C:\PS> Optimize-PSReadlineHistory -MinimumCommandLength 3
    Removes all the duplicate commands and any commands less than 3 characters in length.
.NOTES
    May 15, 2017 - fix bug in handling of multiline commands.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    # Path to the PSReadline history file to optimize.
    [Parameter()]
    [string]
    $HistoryPath,

    # If specified, any commands less than $MinimumCommandLength will be removed from the history file.
    [Parameter()]
    [int]
    $MinimumCommandLength = 1,

    # If specified, any commands other than the last unique $MaximumCommandCount commands will be removed from the history file.
    # Due to principle of least surprise, this defaults to null.
    [Parameter()]
    [Nullable[int]]
    $MaximumCommandCount,

    # If specified, removes leading whitespace from the beginning of the command or the beginning of
    # the first line of multiline commands.
    [Parameter()]
    [switch]
    $TrimLeadingWhitespace,

    # If specified, the check for other PowerShell processes is skipped. You can do this when you are operating on a
    # copy of PSReadline history file.
    [Parameter()]
    [switch]
    $SkipRunningPowerShellCheck
)

if (!$SkipRunningPowerShellCheck) {
    $otherPsProcesses = Get-PSHostProcessInfo | Where-Object ProcessId -ne $pid
    if ($otherPsProcesses) {
        throw "This command can only be run when other PowerShell hosts are not running. Other hosts may have PSReadline loaded.$(($otherPsProcesses | Out-String) -creplace "`n", "`n`t")"
    }
}

if (!$HistoryPath) {
    if ((Get-Module PSReadline -ErrorAction SilentlyContinue) -or (Import-Module PSReadline -ErrorAction SilentlyContinue -PassThru)) {
        $HistoryPath = (Get-PSReadlineOption).HistorySavePath
    }
    else {
        throw "You must provide a value for the HistoryPath parameter."
    }

    Remove-Module PSReadline
    if (Get-Module PSReadline -ErrorAction SilentlyContinue) {
        throw "Failed to remove the PSReadline module. This command can only be run when PSReadline is not loaded."
    }
}

if (![System.IO.Path]::IsPathRooted($HistoryPath)) {
    $HistoryPath = Convert-Path $HistoryPath
}

$history = Get-Content -LiteralPath $HistoryPath -Encoding UTF8
$origFileSize = (Get-Item -LiteralPath $HistoryPath).Length

$strBld = New-Object System.Text.StringBuilder
$commands = New-Object System.Collections.Generic.List[string] -ArgumentList $history.Length
$uniqCommands = New-Object System.Collections.Generic.List[string] -ArgumentList $history.Length

$comparer = if ($IsLinux) { [System.StringComparer]::Ordinal } else { [System.StringComparer]::OrdinalIgnoreCase }
$uniqCommandSet = New-Object System.Collections.Generic.HashSet[string] -ArgumentList $comparer

$numCommands = 0
$numMinLengthCommandsRemoved = 0
$numMultilineCommands = 0

$whatIfMsg = if ($PSBoundParameters['WhatIf']) { 'WHAT IF: ' } else { '' }
$activityMsg = "${whatIfMsg}Optimizing $HistoryPath"

$script:stepCount = 4
$script:step = 0

function Invoke-NextStep {
    param
    (
        [string] $Activity = $activityMsg,
        [switch] $Completed
    )

    Write-Progress -Id 1 -Activity $Activity -PercentComplete (100 * ($script:step++ / $script:stepCount)) -Completed:$Completed
}


Invoke-NextStep

# Process multiline commands in the history file contents
for ($i = 0; $i -lt $history.Count; $i++) {
    if ($i % 100 -eq 0) {
        $percentComplete = [int](100 * ($i + 1) / $history.Count)
        Write-Progress -Id 2 -Activity "Processing multiline commands" -PercentComplete $percentComplete
    }

    $line = $history[$i].TrimEnd()

    if ($line.Length -and $line[-1] -eq '`') {
        $null = $strBld.Append($line + [System.Environment]::NewLine)
    }
    else {
        $numCommands++

        if ($strBld.Length -gt 0) {
            $null = $strBld.Append($line)
            $commandStr = $strBld.ToString()
            $null = $strBld.Clear()
            $numMultilineCommands++
        }
        else {
            $commandStr = $line
        }

        # Trim leading whitesapce if requested
        if ($TrimLeadingWhitespace) {
            $commandStr = $commandStr.TrimStart()
        }

        # This is where we filter out commands that are less than the specified minimum length
        if ($commandStr.Length -ge $MinimumCommandLength) {
            $null = $commands.Add($commandStr)
        }
        else {
            $numMinLengthCommandsRemoved++
        }
    }
}

Write-Progress -Id 2 -Activity "Processing multiline commands" -Completed
Invoke-NextStep

# Walk the history file backwards so we preserve the most recent duplicate command
for ($i = $commands.Count - 1; $i -ge 0 ; $i--) {
    if ($i % 100 -eq 0) {
        $percentComplete = [int](100 * ($history.Count - 1 - $i) / $history.Count)
        Write-Progress -Id 2 -Activity "Removing duplicate commands" -PercentComplete $percentComplete
    }

    # This is where we check for a duplicate command
    $commandStr = $commands[$i]
    if (!$uniqCommandSet.Contains($commandStr)) {
        $null = $uniqCommandSet.Add($commandStr)
        $null = $uniqCommands.Add($commandStr)
    }
}
Write-Progress -Id 2 -Activity "Removing duplicate commands" -Completed
Invoke-NextStep

$uniqCommandSet = $null
$numUniqCommands = $uniqCommands.Count


# PSCRAP: nullable<int>, when null, is improperly handled in PowerShell for inequalities:
# it converts the value to zero.
# You also cannot checkk HasValue so just check against null.
if ($MaximumCommandCount -and $MaximumCommandCount -lt $uniqCommands.Count) {
    Write-Progress -Id 2 -Activity "Removing oldest commands" -PercentComplete 0

    # Over the limit; remove the oldest items from the list.
    # NOTE: Commands are stored newest to oldest, so remove from the *end*!
    $uniqCommands.RemoveRange($MaximumCommandCount, $uniqCommands.Count - $MaximumCommandCount)
}
Write-Progress -Id 2 -Activity "Removing oldest commands" -Completed
Invoke-NextStep

$finalNumCommands = $uniqCommands.Count

# probably don't want this...
if ($finalNumCommands -eq 0) { throw "All commands would be purged." }

if ($PSCmdlet.ShouldProcess($HistoryPath, "Optimize")) {
    Write-Progress -Id 2 -Activity "Saving optimized history" -PercentComplete 0

    Copy-Item -LiteralPath $HistoryPath "${HistoryPath}.bak"
    Remove-Item -LiteralPath $HistoryPath

    $utf8NoBom = [System.Text.UTF8Encoding]::new($false, $true)
    $writer = [System.IO.StreamWriter]::new($HistoryPath, $false, $utf8NoBom)
    try {
        for ($i = $uniqCommands.Count - 1; $i -ge 0 ; $i--) {
            if ($i % 100 -eq 0) {
                $percentComplete = [int](100 * ($uniqCommands.Count - 1 - $i) / $uniqCommands.Count)
                Write-Progress -Id 2 -Activity "Saving optimized history" -PercentComplete $percentComplete
            }

            $line = $uniqCommands[$i]
            $writer.WriteLine($line)
        }
    }
    finally {
        if ($writer) { $writer.Dispose() }
    }

    $newFileSize = (Get-Item -LiteralPath $HistoryPath).Length
}
else {
    # Estimate the resulting file size for -WhatIf
    $newFileSize = 0
    foreach ($command in $uniqCommands) {
        $newFileSize += $command.Length + [System.Environment]::NewLine.Length
    }
}

$strBld = $commands = $uniqCommands = $null

Write-Host "Removed $($numCommands - $numUniqCommands) duplicate commands."
if ($MinimumCommandLength -gt 0) {
    Write-Host "Removed $numMinLengthCommandsRemoved commands with less than $MinimumCommandLength characters."
}
if ($finalNumCommands -lt $numUniqCommands) {
    Write-Host "Removed $($numUniqCommands - $finalNumCommands) commands that were over the desired limit."
}
Write-Host "Number of commands reduced from $numCommands to $finalNumCommands."
Write-Host "Number of multiline commands $numMultilineCommands."
Write-Host ("History file size reduced from {0:F1} KB to {1:F1} KB." -f ($origFileSize / 1KB), ($newFileSize / 1KB))

Invoke-NextStep -Completed
