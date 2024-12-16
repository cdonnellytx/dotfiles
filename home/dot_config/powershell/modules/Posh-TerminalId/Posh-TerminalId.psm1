using namespace System.Collections.Generic
using namespace System.Diagnostics

<#
.SYNOPSIS
    Sets up important OS environment variables.
#>
param()

Set-StrictMode -Version Latest

$TrueColor = 16777216

class PSTerminalInfo
{
    PSTerminalInfo() {}
    PSTerminalInfo([string] $Id)
    {
        $this.Id = $Id
    }

    PSTerminalInfo([string] $Id, [int] $ColorCount)
    {
        $this.Id = $Id
        $this.ColorCount = $ColorCount
    }

    # An identifier for the terminal.
    [string] $Id

    # Equivalent to the `TERM` environment variable.
    [string] $Terminal

    # The color depth, in bits.
    [ValidateSet($null, 1, 16, 256, 16777216)]
    [Nullable[int]] $ColorCount

    hidden [string[]] $Aliases = @()
}

#
# Setup default terminal
#

$DefaultTerminal = [PSTerminalInfo] @{
    Id = 'Unknown'
    ColorCount = 256
}

[PSTerminalInfo[]] $WellKnownTerminalList = @(
    $DefaultTerminal,
    @{ Id = 'powershell_ise' }
    @{ Id = 'screen'; ColorCount = 256 },
    @{ Id = 'tmux'; ColorCount = $TrueColor },
    @{ Id = 'vscode'; ColorCount = $TrueColor; Aliases = @('code') }
    @{ Id = 'WindowsTerminal'; ColorCount = $TrueColor }
    @{ Id = 'JetBrains-JediTerm'; ColorCount = $TrueColor }
    # Visual Studio Terminal: 2022 (17.11+) launches it immediately under devenv.exe, others used to use a hub wrapper.
    @{ Id = 'devenv'; ColorCount = $TrueColor; Aliases = @('VisualStudio', 'ServiceHub.Host.netfx', 'ServiceHub.Host.netfx.x64', 'ServiceHub.Host.netfx.arm64') }

    # winpty-agent is what Vim uses to emulate a terminal on Windows if you shell out.
    # However, winpty-agent is nigh-unmaintained at this point (last release: 2017),
    # and does NOT support 256 colors.
    @{ Id = 'winpty-agent'; ColorCount = 16 }
)


[Hashtable] $WellKnownTerminals = @{}
$WellKnownTerminalList | ForEach-Object {
    $term = $_
    $WellKnownTerminals.Add($term.Id, $term)
    $term.Aliases | ForEach-Object { $WellKnownTerminals.Add($_, $term) }
}

<#
.SYNOPSIS
Gets well-known terminal information by a name.
#>
function Get-WellKnownPSTerminalInfo
{
    [CmdletBinding()]
    [OutputType([PSTerminalInfo])]
    param
    (
        # The terminal name.
        [Parameter(Position = 0, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Id
    )

    $result = $WellKnownTerminals[$Id]
    if ($result)
    {
        return $result
    }

    Write-Error -Category ObjectNotFound -TargetObject $Id -Message "Unknown terminal: '${Id}'"
}

switch ($PSEdition)
{
    'Desktop'
    {
        # PowerShell Desktop -- and .NET Framework -- don't have a nice way to get the parent process ID.
        # There are basically two ways to do it:
        #
        # 1. Use Get-CimInstance to query WMI.
        # 2. Use P/Invoke on ntdll.dll.
        #
        # It is far faster (~0.12s vs ~0.4s) to compile this type dynamically than it is to use WMI to query process info;
        # however, YMMV if your filesystem has lots of security services impacting I/O because I'm pretty sure
        # it generates an assembly to disk before loading it.
        #
        # .SEE https://stackoverflow.com/a/3346055/17152
        Push-Stopwatch -Name 'AddType'
        try
        {
            [Type[]] $types = Add-Type -ErrorAction Stop -PassThru `
                -Namespace 'CDonnelly.Diagnostics' -Name 'ProcessExtensions' `
                -UsingNamespace 'System.ComponentModel',
                    'System.Diagnostics' `
                -MemberDefinition @"

                [StructLayout(LayoutKind.Sequential)]
                private struct ProcessBasicInformation
                {
                    // These members must match PROCESS_BASIC_INFORMATION
                    internal IntPtr Reserved1;
                    internal IntPtr PebBaseAddress;
                    internal IntPtr Reserved2_0;
                    internal IntPtr Reserved2_1;
                    internal IntPtr UniqueProcessId;
                    internal IntPtr InheritedFromUniqueProcessId;
                }


                [DllImport("ntdll.dll")]
                private static extern int NtQueryInformationProcess(IntPtr processHandle, int processInformationClass, ref ProcessBasicInformation processInformation, int processInformationLength, out int returnLength);

                public static Process GetParentProcess(Process process)
                {
                    var processBasicInformation = new ProcessBasicInformation();
                    int returnLength;
                    int status = NtQueryInformationProcess(
                        process.Handle, 0,
                        ref processBasicInformation,
                        Marshal.SizeOf(processBasicInformation),
                        out returnLength);

                    if (status != 0)
                    {
                        throw new Win32Exception(status);
                    }

                    try
                    {
                        return Process.GetProcessById(processBasicInformation.InheritedFromUniqueProcessId.ToInt32());
                    }
                    catch (ArgumentException)
                    {
                        return null;
                    }

                }
"@
            $ProcessExtensions = $types[0]

            function GetParentProcess([Process] $process)
            {
                Push-Stopwatch -Name 'GetParentProcess'
                try
                {
                    return $ProcessExtensions::GetParentProcess($process)
                }
                finally
                {
                    Pop-Stopwatch
                }
            }
        }
        finally
        {
            Pop-Stopwatch
        }
    }
    default
    {
        # PowerShell Core actually exposes process.Parent.
        function GetParentProcess([Process] $process)
        {
            return $process.Parent
        }
    }
}

<#
.PRIVATE
.SYNOPSIS
Gets the parent or ancestor process for the terminal.
#>
function Get-TerminalProcessInfo
{
    [CmdletBinding()]
    [OutputType([Process])]
    param()

    $candidateProcesses = [List[Process]]::new()

    # Crawl parents
    for ($p = Get-Process -Id:$PID; $p; $p = GetParentProcess $p)
    {
        switch ($p.ProcessName)
        {
            # Well-known shells
            'pwsh' { continue }
            'sh' { continue }
            'bash' { continue }
            'elvish' { continue }
            'fish' { continue }
            'ksh' { continue }
            'nu' { continue }
            'tcsh' { continue }
            'xonsh' { continue }
            'zsh' { continue }

            # Well-known shells (Windows)
            'powershell' { if ($IsWindows) { continue } }
            'cmd' { if ($IsWindows) { continue } }

            # Everything else: If it has a window handle, assume it is a terminal.
            # On Windows this is *probably* true, unless it's headless... and I don't really have a way to test headless at the moment.
            default
            {
                if ([IntPtr]::Zero -ne $p.MainWindowHandle)
                {
                    return $p
                }

                $candidateProcesses.Add($p)
            }
        }
    }

    # We didn't find a process with a window handle.
    Write-Warning "No process with a MainWindowHandle was found.`n$($candidateProcesses | Out-String)"

    return $null
}

<#
.SYNOPSIS
Gets the info for the current terminal.
#>
function Get-PSTerminalInfo
{
    [CmdletBinding()]
    [OutputType([PSTerminalInfo])]
    param()

    # Some rules for color detection.
    # @see https://marvinh.dev/blog/terminal-colors/
    #
    # Note I am NOT doing `CI` detection as I don't intend to use this profile in CICD.
    #

    # Search TERM first, since it is more authoritative (Unix).
    if ($Env:TERM)
    {
        $term = [PSTerminalInfo]::new()
        $term.Terminal = $Env:TERM

        # Parse the TERM environment variable.
        [string[]] $parts = $Env:TERM -csplit '-'

        # Identifiers
        $term.Id = $parts[0]
        switch ($parts)
        {
            '24bit' { $term.ColorCount = $TrueColor; break }
            'truecolor' { $term.ColorCount = $TrueColor; break }
            '256' { $term.ColorCount = 256; break }
            '256color' { $term.ColorCount = 256; break }
            'color' { $term.ColorCount = 16; break } # 16 color
            'mono' { $term.ColorCount = 2; break }  # ???
            'dumb' { $term.ColorCount = 2; break }
            default {
                $term.ColorCount = $DefaultTerminal.ColorCount
                break
            }
        }

        return $term
    }

    # There are other environment variables used by various terminals, e.g:
    #   - TERM_PROGRAM
    #   - TERMINAL_EMULATOR (AFAIK this is only a JetBrains thing)
    # However, they share the same flaw: they aren't reliable.
    # TERM is only reliable because it's part of Unix culture to set it if a new terminal emulator opens,
    # but the others aren't guaranteed, *especially* since they vary.

    if ($terminalProcess = Get-TerminalProcessInfo)
    {
        # Try process name
        $term = Get-WellKnownPSTerminalInfo $terminalProcess.ProcessName -ErrorAction SilentlyContinue -ErrorVariable 'err'
        if ($term)
        {
            return $term
        }

        # Try company
        switch -wildcard ($terminalProcess.Company)
        {
            'JetBrains*' { return Get-WellKnownPSTerminalInfo 'JetBrains-JediTerm' }

            default
            {
                Write-Warning "${err}; guessing based on environment."
            }
        }

    }

    # At this point we have nothing to fall back on *but* environment variables.

    # Look next at:
    #   - Specific, well-known terminals
    if ($Env:TERM_PROGRAM)
    {
        $term = Get-WellKnownPSTerminalInfo $Env:TERM_PROGRAM -ErrorAction SilentlyContinue -ErrorVariable 'err'
        if ($term)
        {
            return $term
        }

        Write-Warning "For TERM_PROGRAM: ${err}"
    }

    if ($Env:TERMINAL_EMULATOR)
    {
        $term = Get-WellKnownPSTerminalInfo $Env:TERMINAL_EMULATOR -ErrorAction SilentlyContinue -ErrorVariable 'err'
        if ($term)
        {
            return $term
        }

        Write-Warning "For TERMINAL_EMULATOR: ${err}"
    }

    if ($Env:WT_PROFILE_ID)
    {
        return Get-WellKnownPSTerminalInfo 'WindowsTerminal'
    }

    return $DefaultTerminal
}

# The variable.
New-Variable -Name PSTerminalInfo -Value (Get-PSTerminalInfo) -Option ReadOnly -Visibility Public -Scope Script -Description 'Terminal information'
Export-ModuleMember -Variable 'PSTerminalInfo'