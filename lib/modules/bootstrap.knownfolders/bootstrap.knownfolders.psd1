@{
    RootModule = 'bootstrap.knownfolders.psm1'
    ModuleVersion = '4.2.0'
    GUID = '12ff2f50-7422-4736-a377-fd327e0886c0'
    Author = 'Chris R. Donnelly'
    Copyright = '(c) Chris R. Donnelly. All rights reserved.'
    Description = 'View and manage well-known folders in Windows'

    FunctionsToExport = @(
        'Get-KnownFolder',
        'Set-KnownFolder'
    )
    CmdletsToExport = @()
    VariablesToExport =  @()
    AliasesToExport = @()

    PowerShellVersion = '7.4'
    RequiredModules = @(
        'bootstrap.core'
    )

    FormatsToProcess = @("bootstrap.knownfolders.format.ps1xml")

    FileList = 'bootstrap.knownfolders.psm1'
}
