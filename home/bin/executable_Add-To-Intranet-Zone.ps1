#!/usr/bin/env pwsh
#Requires -Version 5
[CmdletBinding(SupportsShouldProcess=$true)]
param
(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string[]] $hostnames
)

if ((Test-Path Variable:Global:IsWindows) -and !$IsWindows)
{
    throw [PlatformNotSupportedException]::new(('Platform not supported: {0}' -f [Environment]::OSVersion.Platform))
}


# Determine if ESC is on or off.
# @see https://gallery.technet.microsoft.com/scriptcenter/0f4ae77d-1b83-464a-b283-5fa90c2d0dba
function IsEscOn
{
    [CmdletBinding(SupportsShouldProcess=$false)]
    param
    (
    )

    $paths = (
        "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}", # Admin
        "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"  # User
    )
    foreach ($path in $paths)
    {
        if (!(Test-Path -Path $path)) { continue}

        $esc = Get-ItemProperty -Path $path
        if ($esc.IsInstalled) { return $esc.IsInstalled }
    }

    # Not installed
    return 0
}

function Add-MachineToWhiteList
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $domain,
        
        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string[]] $hostnames
    )

    $path = Join-Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap" $domain
    if (!(Test-Path $path)) { throw "Cannot find '$path'" }

    Set-Location $path
    foreach ($hostname in $hostnames)
    {
        # ignore if it already exists
        # (LATER: be smarter)
        if (Test-Path -Path $hostname)
        {
            Write-Verbose "Hostname '$hostname' already whitelisted for domain '$domain'."
            continue
        }

        if ($PSCmdlet.ShouldProcess("Hostname='$hostname', domain='$domain'", 'Whitelist'))
        {
            New-Item $hostname
            New-ItemProperty $hostname -Name file -Value 1 -Type DWORD
        }
    }
}

function Main
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    param
    (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string[]] $hostnames
    )
    Push-Location
    try
    {
        # cdonnelly 2015-08-30: Apparently there is a mode in Windows where,
        # even if you have ESC on, you must whitelist the host in BOTH EscDomains and Domains.
        # This wasn't necessary before...
        Add-MachineToWhiteList "Domains" $hostnames
        if (IsEscOn)
        {
            Add-MachineToWhiteList "EscDomains" $hostnames
        }
    }
    finally
    {
        Pop-Location
    }
}

Main -Hostnames $hostnames
