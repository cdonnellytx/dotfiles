@{
    RootModule = 'bootstrap.fs.psm1'
    ModuleVersion = '0.1.0'
    GUID = '4e1d676e-c364-4259-99d3-6353b258ac7c'
    Author = 'Chris R. Donnelly'
    CompanyName = ''
    Copyright = '(c) Chris R. Donnelly. All rights reserved.'
    FunctionsToExport = @(
        'Get-FileSystemDrive',
        'Confirm-PathIsContainer',
        'Get-BootstrapTempDirectory'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
}

