@{
    RootModule = 'TextUtilityEx.psm1'
    ModuleVersion = '0.2.1'
    GUID = 'da37b5f9-9d25-429b-b61f-b4104aaa983b'

    Author = 'Chris R. Donnelly'
    Copyright = '(c) Chris R. Donnelly. All rights reserved.'
    Description = 'TextUtility extensions'

    PowerShellVersion = '4.0'
    CLRVersion = '4.0'
    DotNetFrameworkVersion = '4.0'
    ProcessorArchitecture = 'None'

    AliasesToExport = @()
    CmdletsToExport = @()
    FunctionsToExport = ('ConvertFrom-Base64Url', 'ConvertTo-Base64Url')
    VariablesToExport = @()

    FileList = 'TextUtilityEx.psm1'
}

