#requires -version 7.0
#requires -modules bootstrap.os

Set-StrictMode -Version Latest

$script:choco = $null

<#
.SYNOPSIS
Gets the Chocolatey app.
.SCOPE
Private
#>
function Resolve-Chocolatey([switch] $PassThru)
{
    if (!$script:choco)
    {
        $choco = Get-Command -Name 'choco.exe' -CommandType Application
        if (!$choco)
        {
            return
        }

        $version = [Version] (& $choco --version)
        if ($version -lt '2.0.0')
        {
            Write-Error -Category InvalidResult -Message "Chocolatey 2.0.0 or later is required (${version} is installed)"
            return
        }

        $script:choco = $choco
    }

    if ($PassThru)
    {
        return $script:choco
    }
}


<#
.SYNOPSIS
Tests whether a package is installed.
#>
function Test-Chocolatey
{
    [CmdletBinding()]
    [OutputType([bool])]
    param
    (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('Name')]
        [string[]] $Id,

        # The source to install via.  Default is empty, meaning the Chocolatey repository.
        [Parameter(ValueFromPipelineByPropertyName)]
        [string[]] $Source
    )

    begin
    {
        Resolve-Chocolatey -ErrorAction Stop
    }

    process
    {
        $arguments = @()
        if ($Source)
        {
            $arguments += '--source', ($Source -join ';')
        }

        $Id | ForEach-Object {
            $result = Get-Chocolatey -Id:$_ -Source:$Source
            if ($VerbosePreference)
            {
                Write-Verbose "$_ => $($result | Out-String)"
            }

            return !!$result
        }
    }
}

filter ConvertFrom-LimitedOutput
{
    $_ | ConvertFrom-Csv -Delimiter '|' -Header 'Id', 'Version'
}

<#
.SYNOPSIS
Searches for a package available for install using the `choco search` command.
#>
function Find-ViaChocolatey
{
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param
    (
        # The name of the package to install.
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias("Name")]
        [string] $Id,

        # The source to install via.  Default is empty, meaning the Chocolatey repository.
        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $Source,

        # Specific version of a package to return.
        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $Version,

        # Only return packages with this exact name.
        [switch] $Exact
    )

    begin
    {
        $choco = Resolve-Chocolatey -ErrorAction Stop
    }

    process
    {
        if ($Source)
        {
            $arguments += '--source', $Source
        }

        if ($Version)
        {
            $arguments += '--version', $Version
        }

        if ($Exact)
        {
            $arguments += '--exact'
        }

        if ($VerbosePreference)
        {
            Write-Verbose "Find via Chocolatey, arguments: ${arguments}"
        }

        & $choco search --limit-output $Id $arguments | ConvertFrom-LimitedOutput
    }
}

<#
.SYNOPSIS
Shows a package available for install using the `choco info` command.
#>
function Show-ViaChocolatey
{
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param
    (
        # The name of the package to install.
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias("Name")]
        [string] $Id,

        # The source to install via.  Default is empty, meaning the Chocolatey repository.
        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $Source,

        # Specific version of a package to return.
        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $Version
    )

    begin
    {
        $choco = Resolve-Chocolatey -PassThru -ErrorAction Stop
    }

    process
    {
        [string[]] $arguments = @()

        if ($Source)
        {
            $arguments += '--source', $Source
        }

        if ($Version)
        {
            $arguments += '--version', $Version
        }

        Write-Verbose "Show via Chocolatey, id: ${Id}, arguments: ${arguments}"

        & $choco info --limit-output $Id $arguments | ConvertFrom-LimitedOutput
    }
}

filter Format-ChocolateyPackageList
{
    $name, $version = $_ -split '\|'

    return [PSCustomObject] @{
        Name = $name
        Version = $version
    }
}

<#
.SYNOPSIS
Displays the packages installed on the system.
#>
function Get-Chocolatey
{
    [CmdletBinding(DefaultParameterSetName = 'List')]
    [OutputType([bool])]
    param
    (
        [Parameter(ParameterSetName = 'Id', Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('Name')]
        [string[]] $Id,

        # The source to install via.  Default is empty, meaning the Chocolatey repository.
        [Parameter(ParameterSetName = 'Id', ValueFromPipelineByPropertyName)]
        [string[]] $Source
    )

    begin
    {
        $choco = Resolve-Chocolatey -PassThru -ErrorAction Stop
    }

    process
    {
        switch ($PSCmdlet.ParameterSetName)
        {
            'List'
            {
                & $choco list --limit-output | Format-ChocolateyPackageList
            }

            'Id'
            {
                $arguments = @()
                if ($Source)
                {
                    $arguments += '--source', ($Source -join ';')
                }

                $Id | ForEach-Object {
                    & $choco list --exact --limit-output $_ $arguments | Format-ChocolateyPackageList
                    if (!$?)
                    {
                        Write-Error -Category InvalidResult -Message "Invalid Chocolatey result"
                        return
                    }
                }
            }
        }
    }
}

<#
.SYNOPSIS
Install a package via Chocolatey.
#>
function Install-ViaChocolatey
{
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        # The name of the package to install.
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias("Name")]
        [string[]] $Id,

        # The source to install via.  Default is empty, meaning the Chocolatey repository.
        [Parameter(ValueFromPipelineByPropertyName)]
        [string[]] $Source,

        # Install Arguments to pass to the native installer in the package.
        [Parameter(ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string] $InstallArguments,

        # A specific version to install.
        [Parameter(ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string] $Version,

        # Force the behavior.
        [Parameter()]
        [switch] $Force,

        # Ignore dependencies when installing package(s).
        [Parameter()]
        [switch] $IgnoreDependencies
    )

    begin
    {
        if (!(Test-IsAdministrator))
        {
            Write-Error -Category PermissionDenied -Message "This function cannot be run because it requires running as Administrator. The current PowerShell session is not running as Administrator. Start PowerShell by using the Run as Administrator option, and then try running the script again."
            break
        }
    }

    process
    {
        $arguments = @('--yes')
        if ($Force)
        {
            $arguments += '--force'
        }
        if ($IgnoreDependencies)
        {
            $arguments += '--ignore-dependencies'
        }
        if ($InstallArguments)
        {
            $arguments += ("--install-arguments={0}" -f $installArguments)
        }
        if ($Version)
        {
            $arguments += '--version', $Version
        }
        if ($Source)
        {
            $arguments += '--source', ($Source -join ';')
        }

        # I seriously thought they had a generic "suppress desktop icon" switch!
        # Chocolatey currently doesn't try to reinstall something already installed as long as Chocolatey installed it.
        $Id | Where-Object {
            if ($Force) { return $true }
            if (Test-Chocolatey $_ -Source $Source) { Write-Information "[chocolatey] Skipping `"${_}`" (installed)"; return $false }
            return $true
        } | ForEach-Object {
            Write-Information "[chocolatey] Installing ${_}"
            if ($PSCmdlet.ShouldProcess("id: ${_}, arguments: ${arguments}", 'Install via Chocolatey'))
            {
                choco.exe install $_ $arguments
            }
        }
    }
}
