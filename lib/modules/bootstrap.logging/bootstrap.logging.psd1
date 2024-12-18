@{
    RootModule = 'bootstrap.logging.psm1'
    ModuleVersion = '0.1.0'
    GUID = 'b8f4489b-7c5a-4080-9627-5a0231839d3b'
    Author = 'Chris R. Donnelly'
    CompanyName = ''
    Copyright = '(c) Chris R. Donnelly. All rights reserved.'
    FunctionsToExport = @(
        'New-BootstrapLog',
        'Write-BootstrapLog'
    )
    CmdletsToExport = @()
    AliasesToExport = @()
    VariablesToExport = @()

    PowerShellVersion = '7.4'
    RequiredModules = @(
        'bootstrap.core'
        'bootstrap.fs'
    )
}
