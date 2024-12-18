#requires -RunAsAdministrator

using namespace System.Security.AccessControl

Set-StrictMode -Version Latest

# MSCRAP: -UseWindowsPowerShell and #requires directives don't work together as of current (7.2.5).
# #requires WebAdministration
if (!(Get-Module WebAdministration))
{
    Import-Module WebAdministration -UseWindowsPowerShell
}


<#
.SYNOPSIS
Grants the app pool permission to read the given folder.
#>
function Grant-PathToAppPool
{
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        [Parameter(Mandatory)]
        [Alias('AppPool')]
        [string] $ApplicationPool,

        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string] $PhysicalPath,

        [Parameter(ValueFromPipelineByPropertyName)]
        [FileSystemRights] $Rights = [FileSystemRights]::Read
    )

    process
    {
        if ($PSCmdlet.ShouldProcess("Application pool: ${ApplicationPool}, Physical path: ${PhysicalPath}", "Grant access"))
        {
            if ($acl = Get-Acl -Path $PhysicalPath)
            {
                $InheritanceFlags = if (Test-Path -LiteralPath $PhysicalPath -PathType Container) { [InheritanceFlags]::ContainerInherit -bor [InheritanceFlags]::ObjectInherit } else { [InheritanceFlags]::None }

                $acl.AddAccessRule([FileSystemAccessRule]::new(
                    "IIS APPPOOL\${ApplicationPool}",
                    $Rights,
                    $InheritanceFlags,
                    [PropagationFlags]::None,
                    [AccessControlType]::Allow
                ))
                $acl | Set-Acl -Path $PhysicalPath
            }
        }
    }
}

<#
.SYNOPSIS
Get or create app pool.
#>
function Confirm-WebAppPool
{
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([object])]
    param
    (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string] $Name
    )

    process
    {
        Write-Verbose "Confirm application pool '${Name}'"
        if ($result = WebAdministration\Get-WebAppPoolState -Name $Name -ErrorAction Ignore)
        {
            return $result
        }

        if ($PSCmdlet.ShouldProcess("Name: ${Name}", "Create application pool"))
        {
            return WebAdministration\New-WebAppPool -Name $Name
        }
    }
}

<#
.SYNOPSIS
Get or create web binding.
#>
function Confirm-WebBinding
{
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([object])]
    param
    (
        # The name of the Web site on which the binding exists / will be created.
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        # The protocol to be used for the Web binding (usually HTTP, HTTPS, or FTP).
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateSet('http', 'https')]
        [string] $Protocol,

        # Specifies the host header (hostname) of the binding.
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('Hostname')]
        [string] $HostHeader,

        # The port used for the binding.
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [uint] $Port
    )

    process
    {
        Write-Verbose "Confirm web binding '${Name}' => '${Protocol}://${HostHeader}:${Port}'"
        if ($binding = WebAdministration\Get-WebBinding -Name $Name -Protocol $Protocol -HostHeader $HostHeader -Port $Port -ErrorAction Ignore)
        {
            # already exists
            return $binding
        }

        if ($PSCmdlet.ShouldProcess("Name: ${Name}, Protocol: ${Protocol}, Binding: '*:${Port}:${HostHeader}'", "Create web binding"))
        {
            $binding = WebAdministration\New-WebBinding -Name $Name -Protocol $Protocol -HostHeader $HostHeader -Port $Port

            # LATER: handle cert.  It sometimes magically works, sometimes doesn't.

            return $binding
        }
    }
}

<#
.SYNOPSIS
Get or create web application.

.EXAMPLE

PS> Confirm-WebApplication -Name xyzzy -Site localhost.contoso.com -PhysicalPath C:\path\to\xyzzy

Site: localhost.contoso.com
Path: /xyzzy
PhysicalPath: C:\path\to\xyzzy

#>
function Confirm-WebApplication
{
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([object])]
    param
    (
        # The application name; will manifest as `${Site}/${Name}`.
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        # The site under which to create the application.
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string] $Site,

        # The physical path to the website content.
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string] $PhysicalPath,

        # The app pool name to use.
        # If not specified, the default for the site will be used.
        [Parameter(ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('AppPool')]
        [string] $ApplicationPool
    )

    process
    {
        Write-Verbose "Confirm web application '${Site}/${Name}'"
        if ($result = WebAdministration\Get-WebApplication -Site $Site -Name $Name -ErrorAction Ignore)
        {
            return $result
        }

        if ($PSCmdlet.ShouldProcess("Name: ${Name}, Site: ${Site}, Application pool: ${ApplicationPool}, Physical path: ${PhysicalPath}", "Create web application"))
        {
            WebAdministration\New-WebApplication -Site $Site -Name $Name -PhysicalPath $PhysicalPath -ApplicationPool $ApplicationPool
        }
    }
}

<#
.SYNOPSIS
Get or create website, plain.
#>
function Confirm-Website
{
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([object])]
    param
    (
        # The web site name.
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        # The physical path to the website content.
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string] $PhysicalPath,

        # The app pool name to use.
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('AppPool')]
        [string] $ApplicationPool,

        # Specifies the default host header (hostname) of the site.
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('Hostname')]
        [string] $HostHeader,

        # Whether the default binding should be HTTP or HTTPS.
        [switch] $Ssl,

        # The HTTP port to use.
        # If none is specified, the default will be chosen based on the `-Ssl` parameter.
        [Parameter(ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [uint] $Port = $Ssl ? 443 : 80
    )

    process
    {
        Write-Verbose "Confirm website '${Name}'"
        if ($result = WebAdministration\Get-Website -Name $Name -ErrorAction Ignore)
        {
            return $result
        }

        if ($PSCmdlet.ShouldProcess("Name: ${Name}, Application pool: ${ApplicationPool}, Binding: '*:${Port}:${HostHeader}, Physical path: ${PhysicalPath}", "Create website"))
        {
            # Create the website with HTTP first, then add HTTPS.
            WebAdministration\New-Website -Name $Name -PhysicalPath $PhysicalPath -ApplicationPool $ApplicationPool -HostHeader $HostHeader -Port $Port
        }
    }
}

#
#
#

<#
.SYNOPSIS
Get or create website, ensuring read permissions as well.
#>
function Confirm-FullWebsite
{
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([object])]
    param
    (
        # The web site name.
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        # The physical path to the website content.
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string] $PhysicalPath,

        # The app pool name to use.
        [Parameter(ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('AppPool')]
        [string] $ApplicationPool = $Name,

        # Specifies the host headers (hostnames) of the site.
        # The first will be the default.
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('Hostname')]
        [string[]] $HostHeader,

        # The HTTP port to use.
        [Parameter(ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [uint] $HttpPort = 80,

        # The HTTPS port to use.
        [Parameter(ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [uint] $HttpsPort = 443,

        # Web applications under the website, if any.
        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias('Applications')]
        [Hashtable[]] $Application,

        # Additional paths to grant to the website and its applications, if any.
        [Parameter(ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string[]] $AdditionalReadPath,

        # Additional paths to grant to the website and its applications, if any.
        [Parameter(ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string[]] $AdditionalWritePath
    )

    process
    {
        Write-Verbose "Confirm full website '${Name}'"

        # First ensure the app pool is created.
        Confirm-WebAppPool -Name $ApplicationPool | Out-Null

        # Create the website with HTTP first, then add HTTPS.
        Confirm-Website -Name $Name -PhysicalPath $PhysicalPath -ApplicationPool $ApplicationPool -HostHeader $HostHeader[0] -Port $HttpPort | Out-Null

        foreach ($hostname in $HostHeader)
        {
            # Ensure HTTP binding.
            Confirm-WebBinding -Name $Name -Protocol 'http' -HostHeader $hostname -Port $HttpPort | Out-Null

            # Ensure HTTPS binding. LATER: handle cert, it seems to Magically Work(TM) right now.
            Confirm-WebBinding -Name $Name -Protocol 'https' -HostHeader $hostname -Port $HttpsPort | Out-Null
        }

        # Ensure the app can read the folder.
        Grant-PathToAppPool -PhysicalPath $PhysicalPath -ApplicationPool $ApplicationPool -Rights ReadAndExecute
        $AdditionalReadPath | Grant-PathToAppPool -ApplicationPool $ApplicationPool -Rights ReadAndExecute
        $AdditionalWritePath | Grant-PathToAppPool -ApplicationPool $ApplicationPool -Rights Modify, Synchronize

        # Regrab with all the latest info
        $website = WebAdministration\Get-Website -Name $Name

        # Ensure applications, if any.
        if ($Application)
        {
            [object[]] $apps = $Application | ForEach-Object {
                $app = Confirm-WebApplication @_ -Site $Name -ApplicationPool $ApplicationPool
                if ($app)
                {
                    Grant-PathToAppPool -PhysicalPath $app.PhysicalPath -ApplicationPool $app.ApplicationPool
                    $AdditionalReadPath | Grant-PathToAppPool -ApplicationPool $app.ApplicationPool -Rights ReadAndExecute
                    $AdditionalWritePath | Grant-PathToAppPool -ApplicationPool $app.ApplicationPool -Rights Modify, Synchronize
                    return $app
                }
            }

            Add-Member -InputObject $website -Type NoteProperty -Name 'Applications' -value $apps
        }

        if (!$website -or $website.State -ne 'Started')
        {
            # and ensure started.
            if ($PSCmdlet.ShouldProcess("Name: ${Name}", "Start website"))
            {
                WebAdministration\Start-Website -Name:$Name
            }
        }

        return $website
    }
}


