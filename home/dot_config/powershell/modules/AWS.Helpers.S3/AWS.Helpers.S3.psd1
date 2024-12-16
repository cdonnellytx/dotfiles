@{
    RootModule = 'AWS.Helpers.S3.psm1'
    ModuleVersion = '0.15.1'
    GUID = '8d66e87d-4e39-4eb3-8a57-8c41cbf0ea08'

    Author = 'Chris R. Donnelly'
    Copyright = '(c) Chris R. Donnelly. All rights reserved.'
    Description = 'S3 helpers for AWS Tools for PowerShell'

    PowerShellVersion = '5.1'
    ProcessorArchitecture = 'None'

    TypesToProcess = @("AWS.Helpers.S3.types.ps1xml")
    FormatsToProcess = @()

    RequiredModules = @(
        'AWS.Helpers.Common'
    )

    AliasesToExport = @()
    CmdletsToExport = @()
    FunctionsToExport = @()
    VariablesToExport = @()
}

