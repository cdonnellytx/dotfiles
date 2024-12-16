@{
    RootModule = 'posh-nuspec.psm1'
    ModuleVersion = '0.10.0'
    GUID = 'e0387d86-b2c5-4e14-9c0c-33bf2c535eef'

    Author = 'Chris R. Donnelly'
    Copyright = '(c) 2023 Chris R. Donnelly. All rights reserved.'
    Description = 'Nuspec file support'
    PowerShellVersion = '7.0'

    FormatsToProcess = @("posh-nuspec.format.ps1xml")
    TypesToProcess = @("posh-nuspec.types.ps1xml")

    FunctionsToExport = @(
        'Get-NuGetCacheLocation',

        'Get-NuGetPackage',
        'Find-NuGetPackage',

        'Read-Nuspec',

        'Get-KnownFramework',
        'Get-FallbackFramework',

        'Show-NuGetTree',

        'Get-AssemblyName'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    NestedModules = @('posh-projectsystem')

    FileList = 'posh-nuspec.psm1'
}

