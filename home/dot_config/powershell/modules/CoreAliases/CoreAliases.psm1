using namespace System.IO

param
(
    # The aliases to include.
    [string[]] $Include = @(),

    # The aliases to exclude.
    [string[]] $Exclude = @(
        # Truly dangerous aliases.
        'curl',
        'wget'
    )
)

Set-StrictMode -Version Latest

$Exports = @{
    Alias = @()
}

# The full set of dangerous Unix aliases (builtins).
$coreAliases = @(
    @{ Name = 'cat';        Value = 'Get-Content';                      Option = 'AllScope'            }
    @{ Name = 'cd';         Value = 'Set-Location';                     Option = 'AllScope'            }
    @{ Name = 'chdir';      Value = 'Set-Location';                     Option = 'AllScope'            }
    @{ Name = 'clear';      Value = 'Clear-Host';                       Option = 'AllScope'            }
    @{ Name = 'compare';    Value = 'Compare-Object';                   Option = 'ReadOnly, AllScope'  }
    @{ Name = 'cp';         Value = 'Copy-Item';                        Option = 'AllScope'            }
    @{ Name = 'cpp';        Value = 'Copy-ItemProperty';                Option = 'ReadOnly, AllScope'  }
    @{ Name = 'curl';       Value = 'Invoke-WebRequest';                Option = 'AllScope'            }
    @{ Name = 'diff';       Value = 'Compare-Object';                   Option = 'ReadOnly, AllScope'  }
    @{ Name = 'dir';        Value = 'Get-ChildItem';                    Option = 'AllScope'            }
    @{ Name = 'echo';       Value = 'Write-Output';                     Option = 'AllScope'            }
    @{ Name = 'kill';       Value = 'Stop-Process';                     Option = 'AllScope'            }
    @{ Name = 'lp';         Value = 'Out-Printer';                      Option = 'AllScope'            }
    @{ Name = 'ls';         Value = 'Get-ChildItem';                    Option = 'AllScope'            }
    @{ Name = 'man';        Value = 'help';                             Option = 'AllScope'            }
    @{ Name = 'mount';      Value = 'New-PSDrive';                      Option = 'AllScope'            }
    @{ Name = 'mv';         Value = 'Move-Item';                        Option = 'AllScope'            }
    @{ Name = 'ps';         Value = 'Get-Process';                      Option = 'AllScope'            }
    @{ Name = 'pwd';        Value = 'Get-Location';                     Option = 'AllScope'            }
    @{ Name = 'ri';         Value = 'Remove-Item';                      Option = 'ReadOnly, AllScope'  }
    @{ Name = 'rm';         Value = 'Remove-Item';                      Option = 'AllScope'            }
    @{ Name = 'rmdir';      Value = 'Remove-Item';                      Option = 'AllScope'            }
    @{ Name = 'sleep';      Value = 'Start-Sleep';                      Option = 'ReadOnly, AllScope'  }
    @{ Name = 'sort';       Value = 'Sort-Object';                      Option = 'ReadOnly, AllScope'  }
    @{ Name = 'tee';        Value = 'Tee-Object';                       Option = 'ReadOnly, AllScope'  }
    @{ Name = 'wget';       Value = 'Invoke-WebRequest';                Option = 'AllScope'            }

    # Other useful aliases.  These aren't AllScope.
    @{ Name = 'which';      Value = 'Get-Command'       }
)

if ($VerbosePreference)
{
    $theRest = $coreAliases | ForEach-Object Name | Where-Object { ($Include -notcontains $_) -and ($Exclude -notcontains $_) -and ($Include -notcontains '*') -and ($Exclude -notcontains '*') }
    Write-Verbose (@{ Include = $Include; Exclude = $Exclude; TheRest = $theRest } | ConvertTo-Json)
}

#
# Add aliases we do want, if they don't exist.
#
if ($Exclude -cnotcontains '*')
{
    if ($Include -ccontains '*')
    {
        [Hashtable[]] $toAdd = $coreAliases
    }
    else
    {
        [Hashtable[]] $toAdd = $coreAliases | Where-Object { $Include -contains $_.Name }
    }

    Write-Verbose "[CoreAliases] Include: ${toAdd}"
    $toAdd | ForEach-Object {
        $fullName =  [Path]::Combine('alias:', $_.Name)
        if (!(Test-Path -LiteralPath $fullName))
        {
            Set-Alias @_ -ErrorAction Stop
            $Exports.Alias += $_.Name
        }
    }
}

#
# Remove aliases we don't want.
# Exclude takes precedence over include.
#
[string[]] $namesToRemove = $Exclude
if ($Include -cnotcontains '*')
{
    $namesToRemove += $coreAliases | Where-Object { $_ -notin $Include }
}

# Remove the aliases we don't want; -Force because some are "read-only".
if ($namesToRemove -and ($pathsToRemove = $namesToRemove | ForEach-Object { [Path]::Combine('alias:', $_) }))
{
    Write-Verbose "[CoreAliases] Remove: ${namesToRemove}"
    Remove-Item -Force -LiteralPath $pathsToRemove -ErrorAction Ignore
    if ($PSEdition -eq 'Desktop')
    {
        # cdonnelly 2017-11-08: PSCRAP (Desktop): must remove twice - script AND global.
        Remove-Item -Force -LiteralPath $pathsToRemove -ErrorAction Ignore
    }

    if ($DebugPreference)
    {
        $pathsToRemove | Where-Object { Test-Path -LiteralPath $_ } | ForEach-Object { Write-Error "CANNOT REMOVE $_" }
    }
}

Export-ModuleMember @Exports
