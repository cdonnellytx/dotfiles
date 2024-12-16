@{
    RootModule = 'EnvironmentHelper.psm1'
    ModuleVersion = '8.0.1'
    GUID = '8db45d4d-42ea-46f0-9d73-648781a8cddf'

    Author = 'Chris R. Donnelly'
    Copyright = '(c) Chris R. Donnelly. All rights reserved.'
    Description = 'Helpers for filtering/setting environment variables, including path environment variables'

    PowerShellVersion = '5.1'
    ProcessorArchitecture = 'None'

    RequiredModules = @('PSVariables')

    FunctionsToExport = @(
        'Get-EnvironmentVariable',
        'Find-EnvironmentVariable',
        'Set-EnvironmentVariable',
        'Remove-EnvironmentVariable',

        'Get-DelimitedEnvironmentVariable',
        'Set-DelimitedEnvironmentVariable',
        'Add-ValueToDelimitedEnvironmentVariable',
        'Remove-ValueFromDelimitedEnvironmentVariable',
        'Update-DelimitedEnvironmentVariable',

        'Get-PathVariable',
        'Set-PathVariable',
        'Add-PathVariable',
        'Remove-PathVariable',
        'Update-PathVariable'
    )

    AliasesToExport = @(
        'env'
    )

    CmdletsToExport = @()
    VariablesToExport = @()

    FileList = 'EnvironmentHelper.psm1'
}

