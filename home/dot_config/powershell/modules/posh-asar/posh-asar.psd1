@{
    RootModule = "posh-asar.psm1"
    CompatiblePSEditions = @('Core', 'Desktop')
    ModuleVersion = '0.1.0'
    GUID = 'b72f809c-fc1a-4b2c-9896-92e79738aebb'

    Author = 'Chris R. Donnelly'
    Copyright = '(c) Chris R. Donnelly. All rights reserved.'
    Description = 'PowerShell cmdlets for working with electron-asar files.'

    PowerShellVersion = '5.1'
    ProcessorArchitecture = 'None'

    RequiredModules = @()

    FormatsToProcess = @("posh-asar.format.ps1xml")

    CmdletsToExport = @(
        'Read-AsarArchive',
        'Get-AsarChildItem'
    )
    VariablesToExport = @()
    AliasesToExport = @()
}

