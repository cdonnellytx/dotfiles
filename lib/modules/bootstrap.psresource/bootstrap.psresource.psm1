using namespace System.Collections.Generic
using namespace System.Diagnostics.CodeAnalysis
using namespace Microsoft.WinGet.Client.PSObjects
using namespace Microsoft.WinGet.Client.Engine.PSObjects

[CmdletBinding(SupportsShouldProcess)]
param()

Set-StrictMode -Version Latest

<#
.SYNOPSIS
Install a package via PSResource if not already installed.
#>
function Install-ViaPSResourceGet
{
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    [OutputType('Microsoft.PowerShell.PSResourceGet.UtilClasses.PSResourceInfo')]
    param
    (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [PowerShellModuleInfo] $InputObject
    )

    process
    {
        Invoke-Operation -Name "Install module '$($InputObject.Name)'" -ScriptBlock {
            if (!(Resolve-Condition $InputObject.Condition))
            {
                Skip-Operation $InputObject.SkipMessage
            }

            if ($installedModule = Get-PSResource -Name $InputObject.Name -ErrorAction Ignore)
            {
                Skip-Operation "v$($installedModule.Version) was already installed"
                return
            }

            Install-PSResource -Name $InputObject.Name
        }
    }
}

class PowerShellModuleInfo
{
    [string] $Name

    # An optional condition (bool or scriptblock)
    $Condition = $null

    # The optional skip message.
    [string] $SkipMessage = $null

    # hashtable to object constructor
    PowerShellModuleInfo()
    {
    }

    # string to object constructor
    PowerShellModuleInfo([string] $Name)
    {
        $this.Name = $Name
    }

    [string] ToString()
    {
        return $this.Name
    }
}
