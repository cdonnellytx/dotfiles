#requires -version 7.2

<#
These commands can be used to export FileInfo settings from $PSStyle and
then import them in another session. You might use the import command in
your PowerShell profile script. The file must be a json file.
#>
Function Export-PSStyleFileInfo {
    [cmdletbinding(SupportsShouldProcess)]
    Param(
        [Parameter(
            Position = 0,
            Mandatory,
            HelpMessage = "Specify the path to a json file."
        )]
        [ValidatePattern("\.json$")]
        [ValidateScript({
                if ( Split-Path $_ | Test-Path) {
                    $true
                }
                else {
                    Throw "Can't validate part of the specified path: $_"
                    $false
                }
            })]
        [string]$FilePath,
        [switch]$NoClobber,
        [switch]$Force
    )
    Begin {
        Write-Verbose "[$((Get-Date).TimeofDay) BEGIN  ] Starting $($myinvocation.mycommand)"
        #initialize a list for extension data
        $ext = [System.Collections.Generic.list[object]]::new()
    } #begin

    Process {
        Write-Verbose "[$((Get-Date).TimeofDay) PROCESS] Exporting PSStyle FileInfo settings to $FilePath "

        $h = @{
            Directory    = $psstyle.FileInfo.Directory
            SymbolicLInk = $psstyle.FileInfo.SymbolicLink
            Executable   = $psstyle.FileInfo.Executable
        }

        Write-Verbose "[$((Get-Date).TimeofDay) PROCESS] Exporting File Extensions"
        foreach ($key in $PSStyle.FileInfo.Extension.keys) {
            Write-Verbose "[$((Get-Date).TimeofDay) PROCESS] --> $key"
            $e = @{Name = $key ; Setting = $psstyle.FileInfo.Extension[$key] }
            $ext.Add($e)
        }
        #add  the extension list to the hashtable
        $h.Add("Extension", $ext)

        $h | ConvertTo-Json | Out-File @PSBoundParameters

    } #process

    End {
        Write-Verbose "[$((Get-Date).TimeofDay) END    ] Ending $($myinvocation.mycommand)"
    } #end

} #close Export-PSStyleFileInfo


Function Import-PSStyleFileInfo {
    [cmdletbinding(SupportsShouldProcess)]
    Param(
        [Parameter(
            Position = 0,
            Mandatory,
            HelpMessage = "Specify the path to a json file."
        )]
        [ValidatePattern("\.json$")]
        [ValidateScript({
                if ( Split-Path $_ | Test-Path) {
                    $true
                }
                else {
                    Throw "Can't validate part of the specified path: $_"
                    $false
                }
            })]
        [string]$FilePath
    )
    Begin {
        Write-Verbose "[$((Get-Date).TimeofDay) BEGIN  ] Starting $($myinvocation.mycommand)"
    } #begin

    Process {
        Write-Verbose "[$((Get-Date).TimeofDay) PROCESS] Importing settings from $FilePath"
        Try {
            $in = Get-Content -Path $FilePath | ConvertFrom-Json -ErrorAction stop
        }
        Catch {
            Throw $_
        }

        $props = "SymbolicLink", "Executable", "Directory"
        foreach ($prop in $props) {
            if ($in.$prop) {
                if ($PSCmdlet.ShouldProcess($prop)) {
                    $psstyle.FileInfo.$prop = $in.$prop
                }
            }
        }

        foreach ($item in $in.extension) {
            if ($pscmdlet.ShouldProcess($item.name)) {
                $psstyle.FileInfo.Extension[$item.name] = $item.setting
            }
        }

    } #process

    End {
        Write-Verbose "[$((Get-Date).TimeofDay) END    ] Ending $($myinvocation.mycommand)"
    } #end

} #close Import-PSStyleFileInfo
