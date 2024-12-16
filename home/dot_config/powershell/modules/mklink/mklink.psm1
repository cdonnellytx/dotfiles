using namespace System.Diagnostics.CodeAnalysis

param()

function mklink
{
    <#
    .FORWARDHELPTARGETNAME New-Item
    .FORWARDHELPCATEGORY Cmdlet
    #>
    [SuppressMessageAttribute('PSShouldProcess', '')]
    [SuppressMessageAttribute('PSReviewUnusedParameter', '')]
    [CmdletBinding(DefaultParameterSetName='pathSet',
        SupportsShouldProcess=$true,
        SupportsTransactions=$true,
        ConfirmImpact='Medium')]
    [OutputType([System.IO.FileSystemInfo])]
    param(
        [Parameter(ParameterSetName='nameSet', Position=0, ValueFromPipelineByPropertyName=$true)]
        [Parameter(ParameterSetName='pathSet', Mandatory=$true, Position=0, ValueFromPipelineByPropertyName=$true)]
        [System.String[]]
        ${Path},

        [Parameter(ParameterSetName='nameSet', Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [AllowNull()]
        [AllowEmptyString()]
        [System.String]
        ${Name},

        [Parameter(Position = 1, Mandatory, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [Alias("Value")]
        [System.Object]
        ${Target},

        [Switch]
        ${Force},

        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [System.Management.Automation.PSCredential]
        ${Credential}
    )

    begin {
        $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('New-Item', [System.Management.Automation.CommandTypes]::Cmdlet)
        $scriptCmd = {& $wrappedCmd -Type SymbolicLink @PSBoundParameters }

        $steppablePipeline = $scriptCmd.GetSteppablePipeline()
        $steppablePipeline.Begin($PSCmdlet)
    }

    process {
        $steppablePipeline.Process($_)
    }

    end {
        $steppablePipeline.End()
    }

}
