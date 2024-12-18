#requires -version 7 -Modules Microsoft.PowerShell.PSResourceGet, bootstrap.ux

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

    process
    {
        Get-PSResourceRepository -Name:$Name | ForEach-Object {
            Invoke-Operation "Trusting PS repository '$($_.Name)'" {
                if ($_.Trusted)
                {
                    Skip-Operation "already trusted"
                }

                $_ | Set-PSResourceRepository -Trusted -WhatIf:$WhatIfPreference
            }
        }
    }
}

#
# Trust the main repo.
#
Confirm-PSResourceRepositoryTrusted -Name 'PSGallery'