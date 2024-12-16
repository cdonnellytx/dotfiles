using namespace System.Collections
using namespace System.IO

Set-StrictMode -Version Latest

# At start, grab a link to the old help
if ($script:OldHelp = Get-Item Function:help -ErrorAction SilentlyContinue)
{
    Remove-Item -ErrorAction SilentlyContinue Function:help
    # When the module removed, set help back to the original function if it exists.
    $ExecutionContext.SessionState.Module.OnRemove = {
        if ($script:OldHelp)
        {
            # restore help to what it was
            # NOTE: Must do this "global" or it won't work!
            Set-Item -Path 'Function:Global:Help' -Value $script:OldHelp
        }
        else
        {
            # can't restore it, just alias it
            Write-Warning "cannot restore default 'help' function, creating alias to Get-Help instead."
            Set-Alias help Get-Help -Scope Global -Option AllScope -Force
        }
    }.GetNewClosure()
}

function help
{

    <#
    .FORWARDHELPTARGETNAME Get-Help
    .FORWARDHELPCATEGORY Cmdlet
    #>
    [CmdletBinding(DefaultParameterSetName='AllUsersView', HelpUri='https://go.microsoft.com/fwlink/?LinkID=113316')]
    param
    (
        [Parameter(Position=0, ValueFromPipelineByPropertyName=$true)]
        [string]
        ${Name},

        [string]
        ${Path},

        [ValidateSet('Alias','Cmdlet','Provider','General','FAQ','Glossary','HelpFile','ScriptCommand','Function','Filter','ExternalScript','All','DefaultHelp','DscResource','Class','Configuration')]
        [string[]]
        ${Category},

        [Parameter(ParameterSetName='DetailedView', Mandatory=$true)]
        [switch]
        ${Detailed},

        [Parameter(ParameterSetName='AllUsersView')]
        [switch]
        ${Full},

        [Parameter(ParameterSetName='Examples', Mandatory=$true)]
        [switch]
        ${Examples},

        [Parameter(ParameterSetName='Parameters', Mandatory=$true)]
        [string[]]
        ${Parameter},

        [string[]]
        ${Component},

        [string[]]
        ${Functionality},

        [string[]]
        ${Role},

        [Parameter(ParameterSetName='Online', Mandatory=$true)]
        [switch]
        ${Online},

        [Parameter(ParameterSetName='ShowWindow', Mandatory=$true)]
        [switch]
        ${ShowWindow}
    )

    # Display the full help topic by default but only for the AllUsersView parameter set.
    if (($psCmdlet.ParameterSetName -eq 'AllUsersView') -and !$Full) {
        $PSBoundParameters['Full'] = $true
    }

    # Nano needs to use Unicode, but Windows and Linux need the default
    $OutputEncoding = if ($IsCoreCLR -and ([System.Management.Automation.Platform]::IsNanoServer -or [System.Management.Automation.Platform]::IsIoT)) {
        [System.Text.Encoding]::Unicode
    } else {
        [System.Console]::OutputEncoding
    }

    $help = Get-Help @PSBoundParameters

    # If a list of help is returned or AliasHelpInfo (because it is small), don't pipe to more
    $psTypeNames = ($help | Select-Object -First 1).PSTypeNames
    if ($psTypeNames -Contains 'HelpInfoShort' -Or $psTypeNames -Contains 'AliasHelpInfo')
    {
        $help
    }
    elseif ($null -ne $help)
    {
        # By default use more on Windows and less on Linux.
        if ($IsWindows) {
            $pagerCommand = 'more.com'
            $pagerArgs = $null
        }
        else {
            $pagerCommand = 'less'
            $pagerArgs = '-s','-P','Page %db?B of %D:.\. Press h for help or q to quit\.'
        }

        # Respect PAGER environment variable which allows user to specify a custom pager.
        # Ignore a pure whitespace PAGER value as that would cause the tokenizer to return 0 tokens.
        if (![string]::IsNullOrWhitespace($env:PAGER)) {
            if (Get-Command $env:PAGER -ErrorAction Ignore) {
                # Entire PAGER value corresponds to a single command.
                $pagerCommand = $env:PAGER
                $pagerArgs = $null
            }
            else {
                # PAGER value is not a valid command, check if PAGER command and arguments have been specified.
                # Tokenize the specified $env:PAGER value. Ignore tokenizing errors since any errors may be valid
                # argument syntax for the paging utility.
                $errs = $null
                $tokens = [System.Management.Automation.PSParser]::Tokenize($env:PAGER, [ref]$errs)

                $customPagerCommand = $tokens[0].Content
                if (!(Get-Command $customPagerCommand -ErrorAction Ignore)) {
                    # Custom pager command is invalid, issue a warning.
                    Write-Warning "Custom-paging utility command not found. Ignoring command specified in `$env:PAGER: $env:PAGER"
                }
                else {
                    # This approach will preserve all the pagers args.
                    $pagerCommand = $customPagerCommand
                    $pagerArgs = if ($tokens.Count -gt 1) {$env:PAGER.Substring($tokens[1].Start)} else {$null}
                }
            }
        }

        $pagerCommandInfo = Get-Command -Name $pagerCommand -ErrorAction Ignore
        if ($null -eq $pagerCommandInfo) {
            $help
        }
        elseif ($pagerCommandInfo.CommandType -eq 'Application') {
            # If the pager is an application, format the output width before sending to the app.
            $consoleWidth = [System.Math]::Max([System.Console]::WindowWidth, 20)

            if ($pagerArgs) {
                # Supply pager arguments to an application without any PowerShell parsing of the arguments.
                # Leave environment variable to help user debug arguments supplied in $env:PAGER.
                $env:__PSPAGER_ARGS = $pagerArgs
                $help | Out-String -Stream -Width ($consoleWidth - 1) | & $pagerCommand --% %__PSPAGER_ARGS%
            }
            else {
                $help | Out-String -Stream -Width ($consoleWidth - 1) | & $pagerCommand
            }
        }
        else {
            # The pager command is a PowerShell function, script or alias, so pipe directly into it.
            $help | & $pagerCommand $pagerArgs
        }
    }
}
