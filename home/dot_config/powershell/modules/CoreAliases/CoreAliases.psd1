@{
    RootModule = 'CoreAliases.psm1'
    ModuleVersion = '4.0.1'
    GUID = '491a43e2-c520-4bae-934b-5a1543cfbbd1'

    Author = 'Chris R. Donnelly'
    Copyright = '(c) Chris R. Donnelly. All rights reserved.'
    Description = 'Core alias management for PowerShell'

    PowerShellVersion = '5.1'
    ProcessorArchitecture = 'None'

    RequiredModules = @(
        'PSVariables'
    )

    # All possible aliases.
    AliasesToExport = @(
        'cat',
        'cd',
        'chdir',
        'clear',
        'compare',
        'cp',
        'cpp',
        'curl',
        'diff',
        'dir',
        'echo',
        'kill',
        'lp',
        'ls',
        'man',
        'mount',
        'mv',
        'ps',
        'pwd',
        'ri',
        'rm',
        'rmdir',
        'sleep',
        'sort',
        'tee',
        'wget',
        'which'
    )
    CmdletsToExport = @()
    FunctionsToExport = @()
    VariablesToExport = @()
}

