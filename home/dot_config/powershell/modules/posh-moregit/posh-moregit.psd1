@{
    RootModule = 'posh-moregit.psm1'
    ModuleVersion = '0.9.3'
    GUID = '7fc633d1-182c-4f6f-9eae-75da35f3dda8'

    Author = 'Chris R. Donnelly'
    Copyright = '(c) 2024 Chris R. Donnelly. All rights reserved.'
    Description = 'More Git methods'

    PowerShellVersion = '7.0'
    ProcessorArchitecture = 'None'

    RequiredModules = @(
        'Microsoft.PowerShell.Utility',
        'posh-git', # for Get-GitStatus
        'PowerGit'  # for Get-GitBranch
    )

    FormatsToProcess = @("posh-moregit.format.ps1xml")
    TypesToProcess = @("posh-moregit.types.ps1xml")

    FunctionsToExport = @(
        'Compare-GitBranch',
        'Update-GitColorCache',
        'Redo-GitBranch'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @(
        'Rebase-GitBranch'
    )
    NestedModules = @()

    FileList = 'posh-moregit.psm1'
}

