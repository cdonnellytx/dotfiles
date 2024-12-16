using namespace System.Collections.Generic
using namespace System.Diagnostics.CodeAnalysis
using namespace System.Management.Automation
using namespace Amazon.Runtime

function Read-TabCompletionFile
{
    [OutputType([string[]])]
    param
    (
        [Parameter(Position = 0, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $ParamName
    )

    $path = Join-Path $PSScriptRoot ("params.${ParamName}.psd1")
    Get-Content -LiteralPath $path | Select-String -NotMatch '^#'
}

#
# Tab Completion
#
if ($PSVersionTable.PSVersion.Major -ge 6)
{
    # Start-AWSSession: ProfileName
    Microsoft.PowerShell.Core\Register-ArgumentCompleter -CommandName 'Start-AWSSession' -ParameterName 'ProfileName' -ScriptBlock {
        param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

        Write-Verbose "argcomplete $commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters"

        Get-AWSCredential -ListProfileDetail | Select-Object -ExpandProperty ProfileName | Where-Object { $_.StartsWith($wordToComplete, [StringComparison]::OrdinalIgnoreCase) }
        @()
    }

    #
    # To import the modules to get the param names, see Register-Params.ps1.
    # MSCRAP: Register-ArgumentCompleter won't export if you run it inside a foreach loop or ForEach-Object cmdlet (PowerShell 7.2.2); unsure why.

    #
    # Bucket: S3 bucket name
    #
    $BucketScriptBlock = {
        param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
        Write-Verbose "argcomplete $commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters"

        if (!$StoredAWSCredentials) { return @() }

        Get-S3Bucket | ForEach-Object BucketName | Where-Object { $_.StartsWith($wordToComplete, [StringComparison]::OrdinalIgnoreCase) }
        @()
    }

    foreach ($ParameterName in 'Bucket', 'BucketName', 'DestinationBucket')
    {
        if ($CommandName = Read-TabCompletionFile $ParameterName)
        {
            Microsoft.PowerShell.Core\Register-ArgumentCompleter -CommandName $CommandName -ParameterName $ParameterName -ScriptBlock $BucketScriptBlock
        }
    }

    #
    # Key: S3 key
    #
    $KeyScriptBlock = {
        param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
        Write-Verbose "argcomplete $commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters"

        if (!$StoredAWSCredentials) { return @() }

        # ONE command uses "Bucket" instead of "BucketName". ONE.
        $bucketName = @($fakeBoundParameters["BucketName"], $fakeBoundParameters["Bucket"]) | Select-Object -First 1
        if ($bucketName)
        {
            # This returns all keys starting with our prefix
            Get-S3Object -BucketName $bucketName -Prefix $wordToComplete | ForEach-Object {
                # Display the suffix but don't split a directory name.
                $pos = $_.Key.LastIndexOf('/', $wordToComplete.Length)
                $suffix = if ($pos -ge 0) { $_.Key.Substring($pos + 1) } else { $_.Key }

                # MSCRAP: if completionValue == tooltip it refuses to show tooltip.  I want to **SEE** it.
                # Make a synthetic one.
                $tooltip = $_.Key + " (size: $($_.Size))"

                return [CompletionResult]::new($_.Key, $suffix, 'ParameterValue', $tooltip)
            }
        }
        else
        {
            Write-Debug "Key completion: no bucket found. Params=$($fakeBoundParameters | ConvertTo-Json -Compress)"
        }

        @()
    }

    foreach ($ParameterName in 'Key', 'DestinationKey', 'Prefix')
    {
        if ($CommandName = Read-TabCompletionFile $ParameterName)
        {
            Microsoft.PowerShell.Core\Register-ArgumentCompleter -CommandName $CommandName -ParameterName $ParameterName -ScriptBlock $KeyScriptBlock
        }
    }

    # # CodeBuild: project name
    # if ($CommandName = Read-TabCompletionFile "CodeBuild.ProjectName")
    # {
    #     Microsoft.PowerShell.Core\Register-ArgumentCompleter -CommandName $CommandName -ParameterName 'ProjectName' -ScriptBlock {
    #         param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    #         Write-Verbose "argcomplete $commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters"

    #         if (!$StoredAWSCredentials) { return @() }

    #         Get-CBProjectList -Select 'Projects' | Where-Object { $_.StartsWith($wordToComplete, [StringComparison]::OrdinalIgnoreCase) } | Sort-Object
    #         @()
    #     }
    # }
}

