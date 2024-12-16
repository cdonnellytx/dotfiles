<#
.SYNOPSIS
Registers current AWS.Tools cmdlets for autocompletion in the AWS.Helpers.Credentials module.
#>
Using Namespace System.Collections.Generic
Using Namespace System.Management.Automation

param()

# Ensure they are all imported.
Get-Module -ListAvailable -Name 'AWS.Tools.*' | Import-Module

function Out-TabCompletionFile
{
    [OutputType([void])]
    param
    (
        [Parameter(Position = 0, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $ParamName,

        [Parameter(ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [CommandInfo[]] $InputObject
    )

    begin
    {
        $items = [List[CommandInfo]]::new()
        [string] $Path = Join-Path $PSScriptRoot ("params.${ParamName}.psd1")
    }

    process
    {
        $items.AddRange($InputObject)
    }

    end
    {
        $data = foreach ($group in ($items | Sort-Object ModuleName, Name | Group-Object ModuleName))
        {
            "# {0}" -f $group.Name
            $group.Group | Select-Object -ExpandProperty Name | Sort-Object
        }
        Out-File -FilePath $Path -InputObject $data
    }
}


# Bucket, BucketName: always an S3 bucket
'Bucket', 'BucketName' | ForEach-Object {
    Get-Command -Type Cmdlet, Alias, Function -Module 'AWS.Tools.*' -ParameterName $_ | Out-TabCompletionFile $_
}

# S3 > Key: only if Bucket/BucketName is also present.
Get-Command -Type Cmdlet, Alias, Function -Module 'AWS.Tools.*' -ParameterName 'Key' | Get-Command -ParameterName 'Bucket', 'BucketName' | Out-TabCompletionFile 'Key'

# S3-specific parameters.
# NOTE: New-EC2SpotDatafeedSubscription has a "Prefix" but it is NOT one of the proper commands to use.
'DestinationBucket', 'DestinationKey' | ForEach-Object {
    Get-Command -Type Cmdlet, Alias, Function -Module 'AWS.Tools.S3' -ParameterName $_ | Out-TabCompletionFile $_
}

# CodeBuild > ProjectName
Get-Command -Type Cmdlet, Alias, Function -Module 'AWS.Tools.CodeBuild' -ParameterName 'ProjectName' | Out-TabCompletionFile 'CodeBuild.ProjectName'