@{
    RootModule = 'AWS.Helpers.Common.psm1'
    ModuleVersion = '0.15.1'
    GUID = 'e7f1cd07-a51f-4e04-b6f3-5a4d9bfe00ea'

    Author = 'Chris R. Donnelly'
    Copyright = '(c) Chris R. Donnelly. All rights reserved.'
    Description = 'Common helpers for AWS Tools for PowerShell'

    PowerShellVersion = '5.1'
    ProcessorArchitecture = 'None'

    RequiredModules = @(
        'AWS.Tools.Common',
        'PsIni'
    )

    AliasesToExport = @()
    CmdletsToExport = @()
    FunctionsToExport = @(
        'Start-AWSSession',
        'Stop-AWSSession',
        'Clear-AWSEnvironment'
    )
    VariablesToExport = @()
}

