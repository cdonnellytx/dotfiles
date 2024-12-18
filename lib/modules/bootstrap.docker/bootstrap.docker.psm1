Set-StrictMode -Version Latest

# Requires Docker to exist.
$docker = Get-Command -Name 'docker' -ErrorVariable err
if (!$docker)
{
    Write-Error -Category NotInstalled -Message "Unable to load module: Docker not installed: ${$err}"
    return
}

<#
.SYNOPSIS
Test whether a Docker container exists.
#>
function Test-DockerContainer
{
    [CmdletBinding()]
    [OutputType([bool])]
    param
    (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string[]] $Name
    )

    process
    {
        $Name | ForEach-Object {
            !!(& $docker ps --all --quiet --filter "name=${_}")
        }
    }
}


