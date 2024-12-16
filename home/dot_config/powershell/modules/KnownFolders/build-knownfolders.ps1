[CmdletBinding(DefaultParameterSetName = 'Path')]
param
(
    [Parameter(ParameterSetName = 'Path')]
    [string] $Path,

    [Parameter(ParameterSetName = 'Registry')]
    [switch] $Registry

)

filter LatestVersion
{
    $_ | Add-Member -PassThru -MemberType ScriptProperty -Name Version -Value {
        [int] $major = 0
        if ([int]::TryParse($this.Name, [ref] $major))
        {
            return [Version]::new($major, 0)
        }

        [Version] $version = $null
        if ([Version]::TryParse($this.Name, [ref] $version))
        {
            return $version
        }

        return $null
    } |
    Where-Object Version |
    Sort-Object -Descending Version |
    Select-Object -First 1
}

filter FormatHashtable([string] $Comment)
{
    begin
    {
        "@{"
        if ($Comment) { "    # {0}" -f $Comment }
    }

    process
    {
        "    '{0}' = '{1}'" -f $_.Name, $_.Id
    }
    end
    {
        "}"
    }
}

switch ($PSCmdlet.ParameterSetName)
{
    'Path'
    {
        $Item = if ($Path)
        {
            Get-Item -Path:$Path
        }
        else
        {
            Get-ChildItem -Directory -LiteralPath "${env:ProgramFiles(x86)}\Windows Kits" | LatestVersion |
                Get-ChildItem -Directory -Filter 'Include' |
                Get-ChildItem -Directory | LatestVersion |
                Get-ChildItem -File -Recurse -Include 'KnownFolders.h' |
                Select-Object -First 1
        }

        if (!$Item)
        {
            return
        }

        $Item | Get-Content -Raw |
            Select-String '// \{(?<Id>[A-F0-9-]{36})\}\r?\nDEFINE_KNOWN_FOLDER\(FOLDERID_(?<Name>\w+)' -AllMatches |
            ForEach-Object Matches |
            Select-Object @{ Name = 'Id'; Expression = { [Guid] $_.Groups['Id'].Value }}, @{ Name = 'Name'; Expression = { $_.Groups['Name'].Value }} |
            Sort-Object Name |
            FormatHashtable -Comment ('Synchronized with Windows SDK {0} KnownFolders.h' -f $Item.Directory.Parent.Name)
    }

    'Registry'
    {
        if ($Registry)
        {
            Get-ChildItem -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions' |
                Get-ItemProperty |
                Select-Object @{ Name = 'Id'; Expression = { [Guid] $_.PSChildName }}, Name |
                Sort-Object Name |
                FormatHashtable -Comment 'From registry'
        }
    }
}
