@{
    RootModule = 'bootstrap.ux.psm1'
    ModuleVersion = '0.1.0'
    GUID = '3c6d79d0-596f-4847-a3d6-b6af8fb71700'
    Author = 'Chris R. Donnelly'
    CompanyName = ''
    Copyright = '(c) Chris R. Donnelly. All rights reserved.'
    FunctionsToExport = @(
        'Write-Progress',
        'Write-Header',
        'Enter-Operation',
        'Invoke-Operation',
        'Exit-Operation',
        'Skip-Operation'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()

    PowerShellVersion = '7.0'
    RequiredModules = @(
        'Microsoft.PowerShell.Utility'
    )
}

