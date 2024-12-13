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
            Write-Operation "Trusting $($_.Name)..."
            if ($_.Trusted)
            {
                Write-Result "OK (already trusted)"
                return
            }

            $_ | Set-PSResourceRepository -Trusted -WhatIf:$WhatIfPreference -ErrorVariable err
            if ($err)
            {
                Write-Result -Err:$err
            }
            else
            {
                Write-Result "OK"
            }
        }
    }
}

Confirm-PSResourceRepositoryTrusted -Name 'PSGallery'