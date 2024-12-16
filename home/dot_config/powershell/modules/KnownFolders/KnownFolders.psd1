@{
    RootModule = 'KnownFolders.psm1'
    ModuleVersion = '4.1.1'
    GUID = '4456fef1-247c-438b-b752-d554a85b1129'

    Author = 'Chris R. Donnelly'
    Copyright = '(c) Chris R. Donnelly. All rights reserved.'
    Description = 'View and manage well-known folders in Windows'

    PowerShellVersion = '5.1'
    ProcessorArchitecture = 'None'

    AliasesToExport = @()
    CmdletsToExport = @()
    FunctionsToExport = @(
        'Get-KnownFolder',
        'Set-KnownFolder'
    )
    VariablesToExport = @()

    FormatsToProcess = @("KnownFolders.format.ps1xml")

    FileList = 'KnownFolders.psm1'
}

