#requires -Version 7 -modules bootstrap.ux

using namespace Microsoft.WinGet.Client.PSObjects

[CmdletBinding(SupportsShouldProcess)]
param()

class ModuleInfo
{
    [string] $Name
    [bool] $Condition = $true

    # The optional skip message.
    [string] $SkipMessage = $null

    # hashtable to object constructor
    ModuleInfo()
    {
    }

    # string to object constructor
    ModuleInfo([string] $Name)
    {
        $this.Name = $Name
    }
}

# Install-PSResource will blindly install the latest.
[ModuleInfo[]] $modules = @(
    @{ Name = 'Microsoft.WinGet.Client'; Condition = $IsWindows; SkipMessage = 'Windows only' }
    'PsIni'
    'wsl'
    'z'
)

$modules | ForEach-Object {
    Invoke-Operation -Name "Install module '$($_.Name)'" -ScriptBlock {
        if (!$_.Condition)
        {
            Skip-Operation $_.SkipMessage
        }

        if ($installedModule = Get-PSResource -Name $_.Name -ErrorAction Ignore)
        {
            Skip-Operation "v$($installedModule.Version) was already installed"
            return
        }

        Install-PSResource -Name $_.Name
    }
} -ErrorAction Stop
