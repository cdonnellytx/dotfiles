@{
    RootModule = 'bootstrap.environment.psm1'
    ModuleVersion = '6.0.3.2'
    GUID = '40f90583-6d4a-49e8-87ff-c8e2bcf48950'
    Author = 'Chris R. Donnelly'
    CompanyName = ''
    Copyright = '(c) Chris R. Donnelly. All rights reserved.'
    Description = 'Helpers for filtering/setting environment variables, including path environment variables'
    FunctionsToExport = @(
        'Get-EnvironmentVariable', 'Find-EnvironmentVariable',
        'Set-EnvironmentVariable', 'Remove-EnvironmentVariable',
        'Get-DelimitedEnvironmentVariable',
        'Set-DelimitedEnvironmentVariable',
        'Add-ValueToDelimitedEnvironmentVariable',
        'Remove-ValueFromDelimitedEnvironmentVariable', 'Get-PathVariable',
        'Set-PathVariable', 'Add-PathVariable', 'Remove-PathVariable',
        'Update-PathVariable'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
}




