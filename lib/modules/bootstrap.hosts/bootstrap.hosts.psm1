Set-StrictMode -Version Latest

# DriverData (Windows 10 1803+) is C:\Windows\System32\Drivers\DriverData
if (!$Env:DriverData)
{
    Write-Error "DriverData environment variable not found."
    return
}

# Find /etc/hosts, it lives in Drivers (not DriverData)
$etcHostsPath = Join-Path (Split-Path $Env:DriverData) 'etc\hosts'

class HostEntry
{
    [ipaddress] $IPAddress
    [string] $Hostname
}

<#
.SYNOPSIS
Get entries from /etc/hosts.
#>
function Get-HostEntry
{
    [OutputType([HostEntry])]
    param
    (
        # Hostname by which to filter
        [Parameter()]
        [string] $IPAddress = '*',

        # Hostname by which to filter
        [Parameter()]
        [string] $Hostname = '*'
    )



    Get-Content -LiteralPath:$etcHostsPath | Select-String '^\s*?(?<IP>[0-9:][0-9.:]+)\s+(?<Hosts>[^#]*)' | ForEach-Object {
        $_.Matches | ForEach-Object {
            $ip = $_.Groups['IP'].Value
            $_.Groups['Hosts'].Value -split '\s+' | ForEach-Object {
                [HostEntry]@{
                    IPAddress = $ip
                    Hostname = $_
                }
            }
        }
    } | Where-Object IPAddress -like $IPAddress | Where-Object Hostname -like $Hostname
}


<#
.SYNOPSIS
Adds entries to `/etc/hosts` if not present.
#>
function Add-HostEntry
{
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param
    (
        # The hostname to add.
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string] $Hostname,

        # The IP address or addresses.
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [IPAddress[]] $IPAddress
    )

    process
    {
        # Add the site to /etc/hosts
        $ExistingIPAddress = Get-HostEntry -Hostname $Hostname | Select-Object -ExpandProperty 'IPAddress'

        $IPAddress | Where-Object { $ExistingIPAddress -notcontains $_ } | ForEach-Object {
            if ($PSCmdlet.SHouldProcess("IP address: ${_}, Hostname: ${Hostname} ", "Add to /etc/hosts"))
            {
                "{0} {1}" -f $_, $Hostname
            }
        } | Add-Content -LiteralPath $etcHostsPath
    }
}

$LoopbackIPAddresses = @([ipaddress]::Loopback, [ipaddress]::IPv6Loopback)

<#
.SYNOPSIS
Adds loopback entries to `/etc/hosts` if not present.
#>
function Add-LoopbackHostEntry
{
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param
    (
        # The hostname to add.
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string] $Hostname
    )

    process
    {
        if ($Hostname -ieq 'localhost')
        {
            # localhost name resolution is handled within DNS itself.
            # Do not add entries.
            return
        }

        Add-HostEntry -Hostname:$Hostname -IPAddress:$LoopbackIPAddresses
    }
}
