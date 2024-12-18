using namespace System.Collections.Generic
using namespace System.IO
using namespace Microsoft.Win32

Set-StrictMode -Version Latest

<#
.PRIVATE
#>
filter Format-Key
{
    $_ -creplace '^(HKEY_\w+):?', {
        switch ($_.Groups[1].Value)
        {
            'HKEY_CURRENT_USER' { 'HKCU:' }
            'HKEY_LOCAL_MACHINE' { 'HKLM:' }
            default { $_ }
        }
    } `
        -ireplace ':\\Software\\', ':\Sof…\' `
        -ireplace '…\\Policies\\', '…\Pol…\' `
        -ireplace '…\\Microsoft\\', '…\Mic…\' `
        -ireplace '…\\Windows\\', '…\Win…\' `
        -creplace '(?<=\\).{40,}?(?=\\)', '...'
}

<#
.SYNOPSIS
Gets the registry entry, or creates it if not found, and ensures it has the given value.
#>
function Confirm-RegistryEntry
{
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        # Specifies a path to one or more locations. Unlike the Path parameter, the value of the LiteralPath parameter is
        # used exactly as it is typed. No characters are interpreted as wildcards. If the path includes escape characters,
        # enclose it in single quotation marks. Single quotation marks tell Windows PowerShell not to interpret any
        # characters as escape sequences.
        [Parameter(Position = 0, Mandatory, ValueFromPipelineByPropertyName)]
        [Alias("PSPath")]
        [ValidateNotNullOrEmpty()]
        [string[]] $LiteralPath,

        # Specifies the name of the registry entry.
        [Parameter(Position = 1, Mandatory, ValueFromPipelineByPropertyName)]
        [string] $Name,

        # Specifies the type of property that this cmdlet adds.
        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias("Type")]
        [Nullable[Microsoft.Win32.RegistryValueKind]] $PropertyType,

        #  Specifies the value of the entry.
        [Parameter(Position = 2, ValueFromPipelineByPropertyName)]
        [object] $Value
    )

    process
    {
        if ($null -eq $PropertyType)
        {
            $PropertyType = if ($Value -is [int]) { [RegistryValueKind]::DWord } else { [RegistryValueKind]::String }
        }

        Confirm-RegistryPath -LiteralPath:$LiteralPath -PassThru | ForEach-Object {
            Invoke-Operation "Ensure registry entry '$($_ | Format-Key)' '${Name}'" {
                if (!($_ | Get-ItemProperty -Name $Name -ErrorAction Ignore))
                {
                    # does not exist, add it
                    $_ | New-ItemProperty -Name $Name -Value $Value -PropertyType $pt
                    return
                }

                # It exists, compare the value
                if ($Value -eq ($_ | Get-ItemPropertyValue -Name $Name))
                {
                    return Skip-Operation "already set"
                }

                $_ | Set-ItemProperty -Name $Name -Value $Value
                return

            }
        }
    }
}

<#
.SYNOPSIS
Gets the registry paths, or creates them if not found.
#>
function Confirm-RegistryPath
{
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Microsoft.Win32.RegistryKey])]
    param
    (
        # Specifies a path to one or more locations. Unlike the Path parameter, the value of the LiteralPath parameter is
        # used exactly as it is typed. No characters are interpreted as wildcards. If the path includes escape characters,
        # enclose it in single quotation marks. Single quotation marks tell Windows PowerShell not to interpret any
        # characters as escape sequences.
        [Parameter(Position = 0, Mandatory, ValueFromPipelineByPropertyName)]
        [Alias("Path")]
        [Alias("PSPath")]
        [ValidateNotNullOrEmpty()]
        [string[]] $LiteralPath,

        # Returns an object that represents the registry key. By default, this cmdlet does not generate any output.
        [switch] $PassThru
    )

    process
    {
        $LiteralPath |
            ForEach-Object {
                if (!$PassThru) { Enter-Operation "Ensure registry path '$($_ | Format-Key)'" }

                if ($result = Get-Item -ErrorAction Ignore -LiteralPath $_)
                {
                    if ($PassThru)
                    {
                        return $result
                    }
                    else
                    {
                        return Skip-Operation "already exists"
                    }
                }

                # MSCRAP: mkdir doesn't create a tree structure in the registry provider.
                # So we have to crawl parents ourselves, and create the parents as needed.

                $selfOrAncestors = [Stack[string]]::new()

                for ($item = $_; $item; $item = Split-Path $item)
                {
                    if (Test-Path -LiteralPath $item)
                    {
                        break
                    }
                    $selfOrAncestors.Push($item)
                }

                # Now create the keys, returning the one the user wants.
                while ($selfOrAncestors.TryPop([ref] $item))
                {
                    $result = New-Item -Path $item
                }

                if ($PassThru)
                {
                    return $result
                }
                else
                {
                    return Exit-Operation $result
                }
            }
    }
}

