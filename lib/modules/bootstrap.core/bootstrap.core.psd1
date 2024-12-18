@{
    RootModule = 'bootstrap.core.psm1'
    ModuleVersion = '0.2.0'
    GUID = 'c2b0aa84-fccf-4df0-abe6-c0d059357278'
    Author = 'Chris R. Donnelly'
    CompanyName = ''
    Copyright = '(c) Chris R. Donnelly. All rights reserved.'
    FunctionsToExport = @('Test-IsTruthy')
    CmdletsToExport = @()
    VariablesToExport =  @()
    AliasesToExport = @()

    # need to keep desktop compatibility for IIS
    PowerShellVersion = '5.1'
    CompatiblePSEditions = @('Core', 'Desktop')
    RequiredModules = @()
}