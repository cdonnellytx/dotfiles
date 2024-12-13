#requires -Version 7 -Modules Microsoft.PowerShell.PSResourceGet, bootstrap.ux

[CmdletBinding(SupportsShouldProcess)]
param()

function Confirm-PSResourceRepositoryTrusted
{
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        [Parameter(Position = 0, Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string[]] $Name
    )

    begin
    {
        Write-Header "Confirm trusted PSResourceRepository"
    }

    process
    {
        Get-PSResourceRepository -Name:$Name | ForEach-Object {
            Enter-Operation "Trusting $($_.Name)"
            if ($_.Trusted)
            {
                Exit-Operation "already trusted"
                return
            }

            $_ | Set-PSResourceRepository -Trusted -WhatIf:$WhatIfPreference -ErrorVariable err
            Exit-Operation -Err:$err
        }
    }
}

#
# Trust the main repo.
#
Confirm-PSResourceRepositoryTrusted -Name 'PSGallery'