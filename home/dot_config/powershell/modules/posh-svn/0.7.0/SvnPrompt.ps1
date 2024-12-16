$global:SvnPromptSettings = [PSCustomObject]@{
    DefaultForegroundColor                  = $null
    DefaultBackgroundColor                  = $null

    BeforeText                              = ' ['
    BeforeForegroundColor                   = [ConsoleColor]::Yellow
    BeforeBackgroundColor                   = $null

    DelimText                               = ' |'
    DelimForegroundColor                    = [ConsoleColor]::Yellow
    DelimBackgroundColor                    = $null

    AfterText                               = ']'
    AfterForegroundColor                    = [ConsoleColor]::Yellow
    AfterBackgroundColor                    = $null

    FileAddedText                           = '+'
    FileModifiedText                        = '~'
    FileRemovedText                         = '-'
    FileConflictedText                      = '!'

    LocalDefaultStatusSymbol                = $null
    LocalDefaultStatusForegroundColor       = [ConsoleColor]::DarkGreen
    LocalDefaultStatusBackgroundColor       = $null

    LocalWorkingStatusSymbol                = '!'
    LocalWorkingStatusForegroundColor       = [ConsoleColor]::DarkRed
    LocalWorkingStatusBackgroundColor       = $null

    LocalStagedStatusSymbol                 = '~'
    LocalStagedStatusForegroundColor        = [ConsoleColor]::Cyan
    LocalStagedStatusBackgroundColor        = $null

    BranchForegroundColor                   = [ConsoleColor]::Cyan
    BranchBackgroundColor                   = $null

    RevisionText                            = '@'
    RevisionForegroundColor                 = [ConsoleColor]::DarkGray
    RevisionBackgroundColor                 = $null

    IndexForegroundColor                    = [ConsoleColor]::DarkGreen
    IndexBackgroundColor                    = $null

    WorkingForegroundColor                  = [ConsoleColor]::DarkRed
    WorkingBackgroundColor                  = $null

    ExternalStatusSymbol                    = [char]0x2190 # arrow right
    ExternalForegroundColor                 = [ConsoleColor]::DarkGray
    ExternalBackgroundColor                 = $null

    IncomingStatusSymbol                    = [char]0x2193 # Down arrow
    IncomingForegroundColor                 = [ConsoleColor]::Red
    IncomingBackgroundColor                 = $null

    ShowStatusWhenZero                      = $true

    EnablePromptStatus                      = !$Global:SvnMissing

    EnableRemoteStatus                      = $true   # show remote server status
    EnableExternalFileStatus                = $false  # include files from externals in counts
    ShowExternals                           = $true

    EnableWindowTitle                       = 'svn ~ '

    # posh-git 1.0 props
    DefaultPromptWriteStatusFirst           = $false
    PathStatusSeparator                     = ' '
    AnsiConsole = $Host.UI.SupportsVirtualTerminal -or ($Env:ConEmuANSI -eq "ON")
}

$WindowTitleSupported = $true
if (Get-Module NuGet) {
    $WindowTitleSupported = $false
}

function Write-Prompt {
    [CmdletBinding(DefaultParameterSetName="Default")]
    param(
        # Specifies objects to display in the console or render as a string if
        # $GitPromptSettings.AnsiConsole is enabled. If the Object is of type
        # [PoshGitTextSpan] the other color parameters are ignored since a
        # [PoshGitTextSpan] provides the colors.
        [Parameter(Mandatory, Position=0)]
        $Object,

        # Specifies the foreground color.
        [Parameter(ParameterSetName="Default")]
        $ForegroundColor = $null,

        # Specifies the background color.
        [Parameter(ParameterSetName="Default")]
        $BackgroundColor = $null,

        # Specifies both the background and foreground colors via [PoshGitCellColor] object.
        [Parameter(ParameterSetName="CellColor")]
        [ValidateNotNull()]
        [PoshGitCellColor]
        $Color,

        # When specified and $GitPromptSettings.AnsiConsole is enabled, the Object parameter
        # is written to the StringBuilder along with the appropriate ANSI/VT sequences for
        # the specified foreground and background colors.
        [Parameter(ValueFromPipeline = $true)]
        [System.Text.StringBuilder]
        $StringBuilder
    )

    if (!$Object -or (($Object -is [PoshGitTextSpan]) -and !$Object.Text)) {
        return $(if ($StringBuilder) { $StringBuilder } else { "" })
    }

    if ($PSCmdlet.ParameterSetName -eq "CellColor") {
        $bgColor = $Color.BackgroundColor
        $fgColor = $Color.ForegroundColor
    }
    else {
        $bgColor = $BackgroundColor
        $fgColor = $ForegroundColor
    }


    $s = $global:SvnPromptSettings
    if ($s) {
        if ($null -eq $fgColor) {
            $fgColor = $s.DefaultColor.ForegroundColor
        }

        if ($null -eq $bgColor) {
            $bgColor = $s.DefaultColor.BackgroundColor
        }

        if ($s.AnsiConsole) {
            if ($Object -is [PoshGitTextSpan]) {
                $str = $Object.ToAnsiString()
            }
            else {
                $e = [char]27 + "["
                $fg = Get-ForegroundVirtualTerminalSequence $fgColor
                $bg = Get-BackgroundVirtualTerminalSequence $bgColor
                $str = "${fg}${bg}${Object}${e}0m"
            }

            return $(if ($StringBuilder) { $StringBuilder.Append($str) } else { $str })
        }
    }

    if ($Object -is [PoshGitTextSpan]) {
        $bgColor = $Object.BackgroundColor
        $fgColor = $Object.ForegroundColor
        $Object = $Object.Text
    }

    $writeHostParams = @{
        Object = $Object;
        NoNewLine = $true;
    }

    if (Test-ConsoleColor $BackgroundColor) {
        $writeHostParams.BackgroundColor = $BackgroundColor
    }

    if (Test-ConsoleColor $ForegroundColor) {
        $writeHostParams.ForegroundColor = $ForegroundColor
    }

    Write-Host @writeHostParams
    return $(if ($StringBuilder) { $StringBuilder } else { "" })
}

function Write-SvnStatus {
    param(
        # The Svn status object that provides the status information to be written.
        # This object is retrieved via the Get-SvnStatus command.
        [Parameter(Position = 0)]
        $Status
    )

    $s = $global:SvnPromptSettings
    if (!$Status -or !$s) {
        return ""
    }

    $sb = [System.Text.StringBuilder]::new(150)

    if ($status -and $s) {
        $sb | Write-Prompt $s.BeforeText -BackgroundColor $s.BeforeBackgroundColor -ForegroundColor $s.BeforeForegroundColor > $null
        $sb | Write-Prompt $status.Branch -BackgroundColor $s.BranchBackgroundColor -ForegroundColor $s.BranchForegroundColor > $null
        $sb | Write-Prompt "$($s.RevisionText)$($status.Revision)" -BackgroundColor $s.RevisionBackgroundColor -ForegroundColor $s.RevisionForegroundColor > $null

        if ($status.HasIndex) {
            if ($s.ShowStatusWhenZero -or $status.Added) {
                $sb | Write-Prompt " $($s.FileAddedText)$($status.Added)" -BackgroundColor $s.IndexBackgroundColor -ForegroundColor $s.IndexForegroundColor > $null
            }
            if ($s.ShowStatusWhenZero -or $status.Modified) {
                $sb | Write-Prompt " $($s.FileModifiedText)$($status.Modified)" -BackgroundColor $s.IndexBackgroundColor -ForegroundColor $s.IndexForegroundColor > $null
            }
            if ($s.ShowStatusWhenZero -or $status.Deleted) {
                $sb | Write-Prompt " $($s.FileRemovedText)$($status.Deleted)" -BackgroundColor $s.IndexBackgroundColor -ForegroundColor $s.IndexForegroundColor > $null
            }
        }

        if ($status.HasWorking) {
            if ($status.HasIndex) {
                $sb | Write-Prompt $s.DelimText -BackgroundColor $s.DelimBackgroundColor -ForegroundColor $s.DelimForegroundColor > $null
            }

            if ($status.Untracked) {
                $sb | Write-Prompt " $($s.FileAddedText)$($status.Untracked)" -BackgroundColor $s.WorkingBackgroundColor -ForegroundColor $s.WorkingForegroundColor > $null
            }

            if ($status.Missing) {
                $sb | Write-Prompt " $($s.FileRemovedText)$($status.Missing)" -BackgroundColor $s.WorkingBackgroundColor -ForegroundColor $s.WorkingForegroundColor > $null
            }

            if ($status.Conflicted) {
                $sb | Write-Prompt " $($s.FileConflictedText)$($status.Conflicted)" -BackgroundColor $s.WorkingBackgroundColor -ForegroundColor $s.WorkingForegroundColor > $null
            }
        }

        if ($status.Incoming) {
            $sb | Write-Prompt " $($s.IncomingStatusSymbol)$($status.Incoming)" -BackgroundColor $s.IncomingBackgroundColor -ForegroundColor $s.IncomingForegroundColor > $null
            $sb | Write-Prompt "$($s.RevisionText)$($status.IncomingRevision)" -BackgroundColor $s.RevisionBackgroundColor -ForegroundColor $s.RevisionForegroundColor > $null
        }

        if ($status.HasIndex) {
            # We have uncommitted files
            $localStatusSymbol          = $s.LocalStagedStatusSymbol
            $localStatusBackgroundColor = $s.LocalStagedStatusBackgroundColor
            $localStatusForegroundColor = $s.LocalStagedStatusForegroundColor
        }
        elseif ($status.HasWorking) {
            # We have uncommitted files
            $localStatusSymbol          = $s.LocalWorkingStatusSymbol
            $localStatusBackgroundColor = $s.LocalWorkingStatusBackgroundColor
            $localStatusForegroundColor = $s.LocalWorkingStatusForegroundColor
        }
        else {
            # No uncommited changes
            $localStatusSymbol          = $s.LocalDefaultStatusSymbol
            $localStatusBackgroundColor = $s.LocalDefaultStatusBackgroundColor
            $localStatusForegroundColor = $s.LocalDefaultStatusForegroundColor
        }

        if ($s.ShowExternals -and $status.External) {
            if ($status.HasWorking -or $status.HasIndex) {
                $sb | Write-Prompt $s.DelimText -BackgroundColor $s.DelimBackgroundColor -ForegroundColor $s.DelimForegroundColor > $null
            }

            $sb | Write-Prompt " $($s.ExternalStatusSymbol)$($status.External)" -BackgroundColor $s.ExternalBackgroundColor -ForegroundColor $s.ExternalForegroundColor > $null
        }

        if ($localStatusSymbol) {
            $sb | Write-Prompt (" {0}" -f $localStatusSymbol) -BackgroundColor $localStatusBackgroundColor -ForegroundColor $localStatusForegroundColor > $null
        }

        $sb | Write-Prompt $s.AfterText -BackgroundColor $s.AfterBackgroundColor -ForegroundColor $s.AfterForegroundColor > $null

        if ($WindowTitleSupported -and $status.Title) {
            $Global:CurrentWindowTitle += ' ~ ' + $status.Title
        }
    }

    $sb.ToString()
}

# Should match https://github.com/dahlbyk/posh-git/blob/master/GitPrompt.ps1
if (!(Test-Path Variable:Global:VcsPromptStatuses)) {
    $Global:VcsPromptStatuses = @()
}

# Add scriptblock that will execute for Write-VcsStatus
$PoshSvnVcsPrompt = {
    try {
        $global:SvnStatus = Get-SvnStatus
        Write-SvnStatus $SvnStatus
    }
    catch {
        $s = $global:SvnPromptSettings
        if ($s) {
            $errorText = "PoshSvnVcsPrompt error: $_"
            $sb = [System.Text.StringBuilder]::new()

            # When prompt is first (default), place the separator before the status summary
            if (!$s.DefaultPromptWriteStatusFirst) {
                $sb | Write-Prompt $s.PathStatusSeparator > $null
            }
            $sb | Write-Prompt $s.BeforeStatus > $null

            $sb | Write-Prompt $errorText -Color $s.ErrorColor > $null
            if ($s.Debug) {
                if (!$s.AnsiConsole) { Write-Host }
                Write-Verbose "PoshSvnVcsPrompt error details: $($_ | Format-List * -Force | Out-String)" -Verbose
            }
            $sb | Write-Prompt $s.AfterStatus > $null

            $sb.ToString()
        }
    }

}

$Global:VcsPromptStatuses += $PoshSvnVcsPrompt
$ExecutionContext.SessionState.Module.OnRemove = {
    $c = $Global:VcsPromptStatuses.Count
    $global:VcsPromptStatuses = @( $global:VcsPromptStatuses | Where-Object { $_ -ne $PoshSvnVcsPrompt -and $_ -inotmatch '\bWrite-SvnStatus\b' } ) # cdonnelly 2017-08-01: if the script is redefined in a different module

    if ($c -ne 1 + $Global:VcsPromptStatuses.Count) {
        Write-Warning "posh-svn: did not remove prompt"
    }
}
