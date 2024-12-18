@{
    RootModule = 'bootstrap.hosts.psm1'
    ModuleVersion = '0.1.0'
    GUID = '4cdadcae-4c63-4449-b82d-29bfbf36e0aa'
    Author = 'Chris R. Donnelly'
    CompanyName = ''
    Copyright = '(c) Chris R. Donnelly. All rights reserved.'
    Description = 'Helpers for /etc/hosts'

    FunctionsToExport = @(
        'Get-HostEntry',
        'Add-HostEntry',
        'Add-LoopbackHostEntry'
    )
    CmdletsToExport = @()
    VariablesToExport = '*'
    AliasesToExport = @()

    PowerShellVersion = '7.4'
    RequiredModules = @(
        'bootstrap.core'
    )
}
