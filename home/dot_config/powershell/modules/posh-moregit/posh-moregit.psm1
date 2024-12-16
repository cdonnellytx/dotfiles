using namespace System
using namespace System.Collections
using namespace System.Collections.Generic
using namespace System.Diagnostics.CodeAnalysis
using namespace System.Globalization
using namespace System.IO
using namespace System.Management.Automation
using namespace System.Reflection
using namespace System.Text
using namespace System.Xml
using namespace System.Xml.Linq

[SuppressMessageAttribute('PSUseCompatibleSyntax', '', Target = '7.0')]
param()

Set-StrictMode -Version Latest

# NOTE: lowercase names in enum for ease of passing to git config
enum BranchColor
{
    current
    local
    remote
    worktree
}

class ColorManager
{
    hidden static [Hashtable] $DefaultColors = @{
        [BranchColor]::current = @{ ForegroundColor = [ConsoleColor]::DarkGreen }
        # # By default Local has no color
        [BranchColor]::local = @{}
        [BranchColor]::remote = @{ ForegroundColor = [ConsoleColor]::DarkRed }
        [BranchColor]::worktree = @{ ForegroundColor = [ConsoleColor]::DarkCyan }
    }

    # LATER: read this out of git config
    hidden [Hashtable] $Colors = @{}

    [bool] TryGetColor([BranchColor] $key, [ref] $result)
    {
        $result.Value = $this.Colors[$key]
        return !!$result.Value
    }

    [void] SetColor([BranchColor] $key, [string] $rawValue)
    {
        $this.Colors[$key] = [ColorManager]::ParseColor($rawValue)
    }

    [void] SetDefaultColor([BranchColor] $key)
    {
        $this.Colors[$key] = [ColorManager]::DefaultColors[$key]
    }

    hidden static [Hashtable] ParseColor([string] $value)
    {
        if (!$value)
        {
            return @{}
        }

        ($name, $parts) = $value -split ' +'
        if ($name -eq 'normal')
        {
            # LATER: handle options-only
            return @{}
        }


        [ConsoleColor] $color = switch ($name)
        {
            'normal' { $global:Host.UI.RawUI.ForegroundColor }
            # Everything else is a valid console color
            default { $name }
        }

        if ($parts -ccontains 'dim' -or !($parts -ccontains 'bold' -or $parts -ccontains 'bright'))
        {
            # Not bold, not bright: they want dark.
            # Fortunately this is an easy transform that doesn't require parsing, but rather just a trick.
            $color = $color - 8
        }

        if ($parts -ccontains 'reverse')
        {
            return @{ BackgroundColor = $value }
        }

        return @{ ForegroundColor = $color }
    }
}

$Script:ColorManager = [ColorManager]::new()

class ConfigColorString
{
    # The text.
    [string] $Text
    # The name of the config setting (e.g., `color.diff.old`).
    [BranchColor] $Color

    ConfigColorString([string] $text, [BranchColor] $color)
    {
        $this.Text = $text
        $this.Color = $color
    }

    [string] ToString()
    {
        [Hashtable] $splat = $null
        if ($Script:ColorManager.TryGetColor($this.Color, [ref] $splat))
        {
            return (New-Text @splat -Object $this.Text).ToString()
        }

        return $this.Text
    }
}

class RefName
{
    [string] $Full
    [string] $Short

    RefName() {}

    RefName([string] $Short)
    {
        $this.Short = $Short
    }

    [string] ToString()
    {
        return $this.Short
    }
}

class UpstreamRefName : RefName
{
    [string] $RemoteName
    [string] $Track
}

class GitBranch : IFormattable
{
    [RefName] $Name
    [UpstreamRefName] $Upstream

    # The current path where the branch is checked out, if any.
    [Alias('PSPath')]
    [Alias('WorktreePath')]
    [string] $Path

    [bool] $IsHead
    [bool] $IsRemote

    [RefName] $SymRef

    hidden [PSCustomObject] $Raw

    GitBranch() {}

    GitBranch([PSCustomObject] $inputObject)
    {
        $this.Raw = $inputObject
        $this.Name = [RefName] @{
            Full = $inputObject.'refname'
            Short = $inputObject.'refname:short'
        }
        $this.IsHead = $inputObject.'HEAD' -eq '*'
        if ($input.'upstream')
        {
            $this.Upstream = [UpstreamRefName] @{
                Full = $inputObject.'upstream'
                Short = $inputObject.'upstream:short'
                RemoteName = $inputObject.'upstream:remotename'
                Track = $inputObject.'upstream:trackshort'
            }
        }

        $this.Path = $inputObject.'worktreepath'

        $this.IsRemote = $this.Name.Full -clike 'refs/remotes/*'
        if ($inputObject.'symref')
        {
            $this.SymRef = [RefName] @{
                Full = $inputObject.'symref'
                Short = $inputObject.'symref:short'
            }
        }

        if ($this.IsRemote -and $this.SymRef)
        {
            # Special case: "short" on "${REMOTE}/HEAD" comes up as "${REMOTE}".
            # Correct the name to match expectations.
            $this.Name = [RefName] @{
                Full = $this.Name.Full
                Short = $inputObject.'refname:lstrip=2' # strip refs/remotes/
            }
        }
    }

    hidden [string] ToHeadString()
    {
        if ($this.IsHead)
        {
            return '*'
        }

        if ($this.Path)
        {
            return '+'
        }

        return ''
    }

    hidden [string] ToAnsiString()
    {
        if ($this.IsHead)
        {
            return [ConfigColorString]::new($this.Name, [BranchColor]::Current).ToString()
        }
        elseif ($this.Path)
        {
            return [ConfigColorString]::new($this.Name, [BranchColor]::Worktree).ToString()
        }
        elseif ($this.IsRemote)
        {
            $result = [ConfigColorString]::new($this.Name, [BranchColor]::Remote).ToString()
            if ($this.SymRef)
            {
                return "{0} -> {1}" -f $result, $this.SymRef.Short
            }

            return $result
        }
        else
        {
            return [ConfigColorString]::new($this.Name, [BranchColor]::Local).ToString()
        }
    }

    [string] ToString()
    {
        return $this.Name
    }

    [string] ToString([string] $format) { return $this.ToString($format, $null) }

    [string] ToString([string] $format, [IFormatProvider] $provider)
    {
        switch ($format)
        {
            '' { return $this.ToString() }
            'G' { return $this.ToString() }
            'HEAD' { return $this.ToHeadString() }
            'ANSI' { return $this.ToAnsiString() }
        }

        throw [ArgumentOutOfRangeException]::new('format', $format)
    }
}

class AheadBehind
{
    [int] $Ahead
    [int] $Behind

    AheadBehind([string] $value)
    {
        $this.Ahead, $this.Behind = $value -split ' ', 2
    }

    hidden [string] ToAnsiString()
    {
        if ($this.Ahead -and $this.Behind)
        {
            return New-Text -ForegroundColor 'Yellow' -Object $this.ToString()
        }
        elseif ($this.Ahead)
        {
            return New-Text -ForegroundColor 'Green' -Object ('↑{0}' -f $this.Behind)
        }
        elseif ($this.Behind)
        {
            return New-Text -ForegroundColor 'Red' -Object ('↓{0}' -f $this.Behind)
        }
        else
        {
            return New-Text -ForegroundColor 'Cyan' -Object '≡'
        }
    }

    [string] ToString()
    {
        return '↑{0} ↓{1}' -f $this.Ahead, $this.Behind
    }

    [string] ToString([string] $format) { return $this.ToString($format, $null) }

    [string] ToString([string] $format, [IFormatProvider] $provider)
    {
        switch ($format)
        {
            '' { return $this.ToString() }
            'G' { return $this.ToString() }
            'ANSI' { return $this.ToAnsiString() }
        }

        throw [ArgumentOutOfRangeException]::new('format', $format)
    }
}

class GitBranchComparison
{
    [GitBranch] $Branch
    [RefName] $Onto
    [AheadBehind] $AheadBehind

    GitBranchComparison([GitBranch] $Branch, [RefName] $Onto, [string] $AheadBehind)
    {
        $this.Branch = $Branch
        $this.Onto = $Onto
        $this.AheadBehind = $AheadBehind
    }
}

[string] $formatDelim = "`t"

# The default Get-GitBranch fields.
[string[]] $GetGitBranchFields = @('refname', 'refname:short', 'upstream', 'upstream:short', 'upstream:remotename', 'upstream:trackshort', 'worktreepath', 'HEAD', 'flag', 'symref', 'symref:short', 'refname:lstrip=2')


<#
.PRIVATE

.SYNOPSIS
Invoke `git branch`.
#>
function Invoke-GitBranch
{
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]] $Field,

        # The optional headers.
        # Defaults to match `Field`.
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]] $Header = $Field,

        # Arguments to `git branch`.
        [string[]] $Arguments
    )

    [string] $format = ($Field | ForEach-Object { '%({0})' -f $_ }) -join $formatDelim

    if ($DebugPreference)
    {
        Write-Debug "Invoking: git branch --format=$(ConvertTo-Json $format) $($arguments | ForEach-Object { ConvertTo-Json $_ })"
    }

    git branch --format=$format $Arguments | ConvertFrom-Csv -Header $Header -Delimiter $formatDelim
}

filter Format-Branch
{
    param
    (
        [switch] $AsRaw
    )

    if ($AsRaw)
    {
        return $_
    }

    return [GitBranch]::new($_)
}

<#
.SYNOPSIS
Gets all the matching branches and compares them to the specified branch name.
#>
function Compare-GitBranch
{
    [CmdletBinding()]
    [OutputType([GitBranchComparison])]
    param
    (
        # The commit or reference to which branches should be compared.
        # Gets ahead/behind status relative to the given commit or ref name.
        # Corresponds to `commitish` in `%(ahead-behind:commitish)`.
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [Alias('Commit')]
        [RefName] $RefName
    )

    [string[]] $Fields = $GetGitBranchFields + ('ahead-behind:{0}' -f $RefName)
    [string[]] $Headers = $GetGitBranchFields + 'AheadBehind'

    Invoke-GitBranch -Field:$Fields -Header:$Headers | ForEach-Object { [GitBranchComparison]::new($_, $RefName, $_.AheadBehind) }
}

function Update-GitColorCache
{
    $colorManager = [ColorManager]::new()

    foreach ($name in [Enum]::GetValues([BranchColor]))
    {
        [string] $value = git config --get "color.branch.${name}"
        if ($value)
        {
            $colorManager.SetColor($name, $value)
        }
        else
        {
            $colorManager.SetDefaultColor($name)
        }
    }

    $Script:ColorManager = $colorManager
}

class InvokeResult
{
    [string[]] $Stdout
    [ErrorRecord[]] $Stderr
    [int] $ExitCode

    InvokeResult([object[]] $Output)
    {
        $this.Stdout = $Output | Where-Object { $_ -isnot [ErrorRecord] }
        $this.Stderr = $Output | Where-Object { $_ -is [ErrorRecord] }
        $this.ExitCode = $LASTEXITCODE
        $this.AddProperties()
    }

    InvokeResult([string[]] $Stdout)
    {
        $this.Stdout = $Stdout
        $this.Stderr = @()
        $this.ExitCode = $LASTEXITCODE
        $this.AddProperties()
    }

    InvokeResult([hashtable] $InputObject)
    {
        $this.Stdout = $InputObject.Stdout ?? @()
        $this.Stderr = $InputObject.Stderr ?? @()
        $this.ExitCode = $InputObject.ExitCode ?? $LASTEXITCODE
        $this.AddProperties()
    }

    <#
    .SYNOPSIS
    Called when there is one stdout line.
    #>
    InvokeResult([string] $StdoutLine)
    {
        $this.Stdout = @($StdoutLine)
        $this.Stderr = @()
        $this.ExitCode = $LASTEXITCODE
        $this.AddProperties()
    }

    InvokeResult([ErrorRecord[]] $Stderr)
    {
        $this.Stdout = @()
        $this.Stderr = $Stderr
        $this.ExitCode = $LASTEXITCODE
        $this.AddProperties()
    }

    <#
    .SYNOPSIS
    Called when there is one stderr line.
    #>
    InvokeResult([ErrorRecord] $ErrorRecord)
    {
        $this.Stdout = @()
        $this.Stderr = @($ErrorRecord)
        $this.ExitCode = $LASTEXITCODE
        $this.AddProperties()
    }

    hidden [void] AddProperties()
    {
        Add-Member -InputObject $this -MemberType ScriptProperty -Name 'Success' -Value { return $this.get_Success() }
    }

    [bool] get_Success()
    {
        return $this.ExitCode -eq 0
    }

    [string] GetErrorSummary()
    {
        return ($this.Stderr | Where-Object { $_.Exception.Message -like 'error:*' } | Out-String)
    }

    [string] ToString()
    {
        switch ($this.ExitCode)
        {
            0
            {
                if ($this.Stdout)
                {
                    return 'ExitCode = {0}; Stdout = {1}' -f $this.ExitCode, ($this.Stdout | Out-String -NoNewline)
                }
                else
                {
                    return 'ExitCode = {0}' -f $this.ExitCode
                }
            }

            { $_ -band 0xFFFFFF00 }
            {
                return 'ExitCode = 0x{0:X8}; StdErr = {1}' -f $this.ExitCode, $this.GetErrorSummary()
            }
        }

        # MSCRAP: switch default is not seen as "always returning"
        return 'ExitCode = {0}; StdErr = {1}' -f $this.ExitCode, $this.GetErrorSummary()
    }
}

function Format-InvocationResult
{
    [CmdletBinding()]
    [OutputType([InvokeResult])]
    param
    (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [object] $InputObject,

        [string] $Activity
    )

    begin
    {
        $Progress = @{
            Id = 0x447440
            Activity = $Activity
            PercentComplete = 0
            Status = ''
        }

        # An additional count to properly count previously-applied commits (when rebasing a downstream branch).
        $PreviouslyAppliedCommitCount = 0

        [List[string]] $stdout = @()
        [List[ErrorRecord]] $stderr = @()
    }

    process
    {
        switch -regex ($InputObject)
        {
            '^(?<Status>Rebasing) \((?<Current>\d+)/(?<Total>\d+)\)$'
            {
                $Progress.Status = $Matches.Status
                switch ($PreviouslyAppliedCommitCount)
                {
                    0 {}
                    1 { $Progress.Status += (' (+{0} applied commit)' -f $PreviouslyAppliedCommitCount) }
                    default { $Progress.Status += (' (+{0} applied commits)' -f $PreviouslyAppliedCommitCount) }
                }
                $Progress.PercentComplete = (($PreviouslyAppliedCommitCount + $Matches.Current) / ($PreviouslyAppliedCommitCount + $Matches.Total) * 100)
                break
            }

            '^warning: skipped previously applied commit .+$'
            {
                # increment the commit count and continue
                $PreviouslyAppliedCommitCount++
            }

            { $_ -is [ErrorRecord] }
            {
                if ($_.Exception)
                {
                    $Progress.Status = $_.Exception.Message
                }
                else
                {
                    $Progress.Status = $_
                }
                $stderr.Add($_)
                Write-Information -Tags 'stderr' -MessageData $_
            }

            default
            {
                $Progress.Status = $_
                $stdout.Add($_)
                Write-Information -Tags 'stdout' -MessageData $_
            }
        }

        Write-Progress @Progress -Status:$_
    }

    clean {
        Write-Progress -Id:$Progress.Id -Completed
    }

    end
    {
        return [InvokeResult] @{
            Stdout = $stdout
            Stderr = $Stderr
            ExitCode = $LASTEXITCODE
        }
    }
}

class RedoGitBranchResult
{
    hidden [GitBranchComparison] $Compare
    [RefName] $Branch
    [RefName] $Onto
    [string] $Status = 'Unknown'
    [InvokeResult] $Switch
    [InvokeResult[]] $Rebase = @()
    [InvokeResult] $Push
    [InvokeResult] $Abort

    RedoGitBranchResult([GitBranchComparison] $Compare)
    {
        $this.Compare = $Compare
        $this.Branch = $Compare.Branch.Name
        $this.Onto = $Compare.Onto
    }

    RedoGitBranchResult([GitBranchComparison] $Compare, [string] $Status)
    {
        $this.Compare = $Compare
        $this.Branch = $Compare.Branch.Name
        $this.Onto = $Compare.Onto
        $this.Status = $Status
    }

    [InvokeResult] GetDetails()
    {
        switch ($this.Status)
        {
            'AbortError' { return $this.Abort }
            'PushError' { return $this.Push }
            'SwitchError' { return $this.Switch }
            'Conflict'
            {
                # Last rebase
                return $this.Rebase[-1]
            }
        }

        # Nothing else
        return $null
    }
}

<#
.SYNOPSIS
Rebase all matching branches
#>
function Redo-GitBranch
{
    [CmdletBinding(SupportsShouldProcess)]
    [SuppressMessageAttribute('PSUseApprovedVerbs', '')]
    [SuppressMessageAttribute('PSAvoidShouldContinueWithoutForce', '', Justification = 'Interactive is the anti-Force')]
    [OutputType([RedoGitBranchResult])]
    param
    (
        # The branch or branches to rebase.
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [string[]] $Target,

        # The onto branch.
        # If none specified, will use the default branch (per GitHub).
        [Parameter(Position = 1)]
        [ValidateNotNullOrEmpty()]
        [Alias('Commit')]
        [Alias('RefName')]
        [RefName] $Onto = (git default-branch),

        # When set, processes things interactively (does not immediately abort.)
        [Parameter()]
        [switch] $Interactive
    )

    begin
    {
        $git = Get-Command -Type Application -Name 'git' -ErrorAction Stop
        $yesToAll = [ref]::new($false)
        $noToAll = [ref]::new($false)

        [string[]] $rebaseOptions = '--update-refs'
    }

    process
    {
        # First resolve the branches.
        $targetBranches = $Target | ForEach-Object { Get-GitBranch -Name:$_ }

        # Now determine which branches are behind, rebasing ones nearer to the target first,
        # then rebasing any branches downstream to the rebased branch to preserve the tree.
        #
        # .EXAMPLE
        #
        # Rebasing the tree onto main after an update:
        #
        #  main~1 -----> A -----> B
        #                |
        #                |------> C
        #
        # The steps should be:
        #   1. Rebase A onto main (rebased!A)
        #   2. Rebase B onto rebased!A
        #   3. Rebase C onto rebased!A

        # Keep track of all emitted refs.
        $emitted = [HashSet[string]]::new()

        Compare-GitBranch -RefName:$Onto |
            Where-Object Branch -cin $targetBranches.Name |
            Where-Object Behind -gt 0 |
            Sort-Object Ahead |
            ForEach-Object {
                if (!$emitted.Add($_.Branch.Name))
                {
                    Write-Verbose "Skipping reprocessing of $($_.Branch.Name): was reprocessed downstream"
                    return
                }
                # Get all branches downstream of this one (0 behind, >0 ahead).
                $_ | Add-Member -PassThru -NotePropertyName 'Downstream' -NotePropertyValue ([GitBranchComparison[]] (Compare-GitBranch -RefName:$_.Branch.Name | Where-Object Behind -eq 0 | Where-Object Ahead -gt 0) ?? @())
            } |
            ForEach-Object {
                $result = [RedoGitBranchResult]::new($_)

                if (!$PSCmdlet.ShouldProcess("Branch: $($_.Branch), onto branch: $($_.Onto)", "Rebase branch"))
                {
                    $result.Status = 'DryRun'
                    return $result
                }

                # Switch operation
                # Start-GitRebase (0.9.0) seems to have libgit2 (0.26.0.0) hell issues...
                $result.Switch = & $git switch $result.Branch 2>&1 | Format-InvocationResult -Activity:$($result.Branch)
                if ($result.Switch.ExitCode -ne 0)
                {
                    $result.Status = 'SwitchError'
                    return $result
                }

                # Rebase operation
                $rebase = & $git rebase @rebaseOptions $result.Onto 2>&1 | Format-InvocationResult -Activity:$($result.Branch)
                $result.Rebase += $rebase
                if ($rebase.ExitCode -ne 0)
                {
                    # We have a conflict.  Abort by default.
                    $result.Status = 'Conflict'
                    if (!$Interactive)
                    {
                        $result.Abort = & $git rebase --abort 2>&1 | Format-InvocationResult -Activity:$($result.Branch)
                        if ($result.Abort.ExitCode -ne 0)
                        {
                            $result.Status = 'AbortError'
                            if ($result.Abort.Stderr)
                            {
                                # While I would like to have us just stop here, I cannot, because that kills any streaming variables.
                                # LATER: Debug why this keeps happening.
                                return $result
                            }
                        }

                        return $result
                    }

                    # The process is interactive.  Ask the user to fix this.
                    do
                    {
                        Write-Warning ($rebase.Stderr | Out-String)
                        if ($PSCmdlet.ShouldContinue("Abort rebase of branch '$($result.Branch)' onto '$($result.Onto)'?", 'Confirmation', $yesToAll, $noToAll))
                        {
                            # User selected "Yes", to "Abort".
                            $result.Abort = & $git rebase --abort 2>&1 | Format-InvocationResult -Activity:$($result.Branch)
                            return $result
                        }

                        # The process is interactive and we were told not to abort.
                        # See if the branch is fixed -- which would be the case if the user suspended it and fixed it manually.
                        $status = posh-git\Get-GitStatus
                        if ($status.HasWorking -or $status.HasUntracked)
                        {
                            # The conflict is not resolved.  Do not abort, but do not continue.
                            return $result
                        }

                        if (!$status.HasIndex)
                        {
                            # The repo looks clean, presume that it is fixed.
                            break
                        }

                        # Continue the rebase.
                        $rebase = & $git rebase --continue 2>&1 | Format-InvocationResult -Activity:$($result.Branch)
                        $result.Rebase += $rebase
                    }
                    while ($rebase.ExitCode -ne 0)

                    # The conflict appears to be resolved.
                    # Fall through to "Success".
                }

                $result.Status = 'Success'
                return $result
            } |
            ForEach-Object {
                # Push
                $result = $_
                if ($result.Status -ne 'Success')
                {
                    # This branch did not rebase, do not push.
                    return $result
                }

                if ($gitStatus = posh-git\Get-GitStatus | Where-Object { $_.Upstream -and !$_.UpstreamGone })
                {
                    if ($ConfirmPreference -ge 'High' -or $PSCmdlet.ShouldContinue("Push $($_.Branch) to $($gitStatus.Upstream)?", "Confirm"))
                    {
                        $result.Push = & $git push --force-with-lease --porcelain 2>&1 | Format-InvocationResult -Activity:$($_.Branch)
                        if ($result.Push.ExitCode -ne 0)
                        {
                            $result.Status = 'PushError'
                        }
                    }
                }

                return $result
            } |
            ForEach-Object {
                $result = $_

                # Emit object unless it's a dry-run.
                switch ($result.Status)
                {
                    'Success'
                    {
                        Write-Output $result
                        if ($result.Compare.Downstream)
                        {
                            Redo-GitBranch -Onto $result.Branch -Target $result.Compare.Downstream.Branch.Name | ForEach-Object {
                                $childResult = $_
                                if ($emitted.Add($childResult.Branch))
                                {
                                    Write-Output $childResult
                                }
                                else
                                {
                                    Write-Warning "Already emitted $($childResult.Branch)!"
                                }
                            }
                        }
                    }

                    'DryRun'
                    {
                        # do NOT emit, mark all downstream as rebasing to our branch.
                        $result.Compare.Downstream | ForEach-Object {
                            $childCompare = $_
                            if ($emitted.Add($childCompare.Branch.Name))
                            {
                                $PSCmdlet.ShouldProcess("Branch: $($childCompare.Branch), onto branch: $($childCompare.Onto) (or further downstream)", "Rebase branch")
                            }
                            else
                            {
                                Write-Warning "Already emitted $($childCompare.Branch.Name)!"
                            }
                        }
                    }

                    default
                    {
                        # Emit the failure and placeholders for downstream.
                        Write-Output $result

                        $result.Compare.Downstream | ForEach-Object {
                            $childCompare = $_
                            if ($emitted.Add($childCompare.Branch.Name))
                            {
                                Write-Output ([RedoGitBranchResult]::new($childCompare, 'DidNotAttempt'))
                            }
                            else
                            {
                                Write-Warning "Already emitted $($childCompare.Branch.Name)!"
                            }
                        }
                    }
                }
            }
    }
}

New-Alias -Name 'Rebase-GitBranch' -Value 'Redo-GitBranch'

#
# Main
#

# Update the color cache at start.
Update-GitColorCache