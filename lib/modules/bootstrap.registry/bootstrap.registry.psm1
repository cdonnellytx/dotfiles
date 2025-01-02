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
Ensures the registry key exists and its property has the given value.
#>
function Confirm-RegistryProperty
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

        #  Specifies the value of the entry.
        [Parameter(Position = 2, ValueFromPipelineByPropertyName)]
        [object] $Value,

        # Specifies the type of property that this cmdlet adds.
        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias("Type")]
        [Nullable[Microsoft.Win32.RegistryValueKind]] $PropertyType = (if ($Value -is [int]) { [RegistryValueKind]::DWord } else { [RegistryValueKind]::String }),

        # An optional script block to run if the change is applied.
        [scriptblock] $OnChange
    )

    process
    {
        Confirm-RegistryItem -LiteralPath:$LiteralPath -PassThru | ForEach-Object {
            Enter-Operation "Ensure registry entry '$($_ | Format-Key)' '${Name}'"
            try
            {
                if (!($_ | Get-ItemProperty -Name $Name -ErrorAction:Ignore))
                {
                    # does not exist, add it
                    $_ | New-ItemProperty -Name $Name -Value $Value -PropertyType $PropertyType
                }
                # It exists, compare the value
                elseif ($Value -eq ($_ | Get-ItemPropertyValue -Name $Name))
                {
                    Skip-Operation "already set"
                    return
                }
                else
                {
                    $_ | Set-ItemProperty -Name $Name -Value $Value -PropertyType $PropertyType
                }

                if ($OnChange)
                {
                    & $OnChange
                }
                Exit-Operation
            }
            catch
            {
                Exit-Operation $_
            }

        }
    }
}

function mkitem([string] $LiteralPath)
{
    # MSCRAP: mkdir doesn't create a tree structure in the registry provider.
    # So we have to crawl parents ourselves, and create the parents as needed.
    $selfOrAncestors = [Stack[string]]::new()

    for ($item = $LiteralPath; $item; $item = Split-Path $item)
    {
        if (Test-Path -LiteralPath $item)
        {
            break
        }
        $selfOrAncestors.Push($item)
    }

    if ($selfOrAncestors.Count -eq 0)
    {
        # oh, it already exists?
        Write-Warning "Path already exists! ${LiteralPath}"
        return Get-Item -LiteralPath:$LiteralPath
    }

    # Now create the keys, returning the one the user wants.
    while ($selfOrAncestors.TryPop([ref] $item))
    {
        $result = New-Item -Path $item
    }

    return $result
}

<#
.SYNOPSIS
Ensures the given registry key exists.
#>
function Confirm-RegistryItem
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

                $result = mkitem $_

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

