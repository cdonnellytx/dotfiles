@{
    RootModule = 'SshHelper.psm1'
    ModuleVersion = '0.8.2'
    GUID = 'c30b6e32-f94b-413c-9744-b4aa09cf0ecc'

    Author = 'Chris R. Donnelly'
    Copyright = '(c) Chris R. Donnelly. All rights reserved.'
    Description = 'SSH manager for PowerShell'

    PowerShellVersion = '5.1'
    CLRVersion = '4.0'
    DotNetFrameworkVersion = '4.5'
    ProcessorArchitecture = 'None'

    RequiredModules = @(
        'PSVariables'
    )

    AliasesToExport = @()
    CmdletsToExport = @()
    FunctionsToExport = @('Test-SshAgent', 'Initialize-SshAgent')
    VariablesToExport = @('ssh')
}

