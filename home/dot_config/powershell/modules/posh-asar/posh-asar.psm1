using namespace System.IO
using namespace System.Text
using namespace System.Text.Json

param()

Set-StrictMode -Version Latest

class AsarFileSystemInfo
{
    [string] $Name
  #  hidden [PSCustomObject] $RawData

    static hidden [Hashtable[]] $MemberDefinitions = @(
        @{
            MemberName = 'FullName'
            MemberType = 'ScriptProperty'
            Value = { $this.GetFullName() }
        }
        @{
            MemberName = 'Mode'
            MemberType = 'ScriptProperty'
            Value = { $this.GetMode() }
        }
        @{
            MemberName = 'PSPath'
            MemberType = 'ScriptProperty'
            Value = { $this.GetFullName() }
        }
        @{
            MemberName = 'PSParentPath'
            MemberType = 'ScriptProperty'
            Value = { $this.GetPSParentPath() }
        }
    )

    static AsarFileSystemInfo()
    {
        Write-Warning "running static ctor"
        $TypeName = [AsarFileSystemInfo].FullName
        foreach ($Definition in [AsarFileSystemInfo]::MemberDefinitions)
        {
            Update-TypeData -TypeName:$TypeName @Definition -Force
        }
    }

    AsarFileSystemInfo([string] $name, [PSCustomObject] $rawData)
    {
        $this.Name = $name
      #  $this.RawData = $rawData
    }

    hidden [string] GetFullName()
    {
        [StringBuilder] $sb = [StringBuilder]::new()
        $this.AppendFullName($sb)
        return $sb.ToString()
    }

    hidden [string] GetPSParentPath()
    {
        throw [System.NotImplementedException]::new("For type: $($this.GetType())")
    }

    hidden [string] GetMode()
    {
        throw [System.NotImplementedException]::new("For type: $($this.GetType())")
    }

    [void] AppendFullName([StringBuilder] $builder)
    {
        $builder.Append($this.Name)
    }

    [string] ToString()
    {
        return $this.GetFullName()
    }
}

class AsarDirectoryInfo : AsarFileSystemInfo
{
    [AsarDirectoryInfo] $Parent

    AsarDirectoryInfo([string] $name, [PSCustomObject] $rawData) : base($name, $rawData)
    {
    }

    AsarDirectoryInfo([AsarDirectoryInfo] $parent, [string] $name, [PSCustomObject] $rawData) : base($name, $rawData)
    {
        $this.Parent = $parent
    }

    [void] AppendFullName([StringBuilder] $builder)
    {
        if ($this.Parent)
        {
            $this.Parent.AppendFullName($builder)
            $builder.Append('/')
        }

        $builder.Append($this.Name)
    }

    hidden [string] GetPSParentPath()
    {
        return $this.Parent?.PSPath
    }

    hidden [string] GetMode()
    {
        return 'd----'
    }
}

class AsarFileInfo : AsarFileSystemInfo
{
    [AsarDirectoryInfo] $Directory
    <#
        .SYNOPSIS
        The offset of the file in the archive, if packed.
        .NOTES
        Unpacked files have no offset.
    #>
    [Nullable[long]] $Offset
    [long] $Size
     <#
     Whether the file has been unpacked to the file system.
     .LINK
     https://www.electronjs.org/docs/latest/tutorial/asar-archives#adding-unpacked-files-to-asar-archives
     #>
    [bool] $Unpacked = $false

    AsarFileInfo([AsarDirectoryInfo] $directory, [string] $name, [PSCustomObject] $rawData) : base($name, $rawData)
    {
        $this.Directory = $directory
        $this.Size = $rawData.Size

        if ($rawData.PSObject.Properties.Name -eq 'unpacked')
        {
            $this.Unpacked = $rawData.unpacked
        }
        else
        {
            $this.Offset = $rawData.offset
        }
    }

    [void] AppendFullName([StringBuilder] $builder)
    {
        if ($this.Directory)
        {
            $this.Directory.AppendFullName($builder)
            $builder.Append('/')
        }

        $builder.Append($this.Name)
    }

    hidden [string] GetPSParentPath()
    {
        return $this.Directory?.PSPath
    }

    hidden [string] GetMode()
    {
        return $this.Unpacked ? '-u---' : '-----'
    }
}

function Get-AsarChildItem
{
    [CmdletBinding(DefaultParameterSetName = "Path")]
    param
    (
        # Specifies a path to one or more locations. Wildcards are permitted.
        [Parameter(ParameterSetName = "Path", Position = 0, Mandatory,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName,
            HelpMessage = "Path to one or more locations.")]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [string[]] $Path,

        # Specifies a path to one or more locations. Unlike the Path parameter, the value of the LiteralPath parameter is
        # used exactly as it is typed. No characters are interpreted as wildcards. If the path includes escape characters,
        # enclose it in single quotation marks. Single quotation marks tell Windows PowerShell not to interpret any
        # characters as escape sequences.
        [Parameter(
            ParameterSetName = "LiteralPath",
            Position = 0, Mandatory,
            ValueFromPipelineByPropertyName,
            HelpMessage = "Literal path to one or more locations.")]
        [Alias("PSPath")]
        [ValidateNotNullOrEmpty()]
        [string[]] $LiteralPath,

        # To get a list of files, use the `File` parameter.
        [Parameter()]
        [switch] $File,

        # To get a list of directories, use the `Directory` parameter.
        [Parameter()]
        [switch] $Directory,

        # Specifies an array of one or more string patterns to be matched as the cmdlet gets child items.
        # Any matching item is included in the output.
        [Parameter()]
        [SupportsWildcards()]
        [string[]] $Include,

        # Specifies an array of one or more string patterns to be matched as the cmdlet gets child items.
        # Any matching item is excluded from the output.
        [Parameter()]
        [SupportsWildcards()]
        [string[]] $Exclude
    )

    begin
    {
        filter ReadAsarFileInfo([AsarDirectoryInfo] $DirectoryInfo = $null)
        {
            #$props = Get-Member -MemberType NoteProperty -InputObject $_.files

            foreach ($prop in $_.files.PSObject.Properties)
            {
                $name = $prop.Name
                $value = $prop.Value

                if ($value.PSObject.Properties.Name -eq 'size')
                {
                    # file entry
                    $childInfo = [AsarFileInfo]::new($DirectoryInfo, $name, $value)

                    if ($DebugPreference)
                    {
                        Add-Member -InputObject $item -NotePropertyName 'RawData' -NotePropertyValue $value
                    }
                    Write-Output $childInfo
                }
                else
                {
                    # directory entry
                    $childInfo = [AsarDirectoryInfo]::new($DirectoryInfo, $name, $value)

                    if ($DebugPreference)
                    {
                        Add-Member -InputObject $item -NotePropertyName 'RawData' -NotePropertyValue $value
                    }
                    Write-Output $childInfo

                    $value | ReadAsarFileInfo -DirectoryInfo $childInfo
                }
            }
        }
        filter FilterItems([switch] $File, [switch] $Directory, [string[]] $Include, [string[]] $Exclude)
        {
            $item = $_
            if ($File -and $item -is [AsarDirectoryInfo]) { return }
            if ($Directory -and $item -is [AsarFileInfo]) { return }
            if ($Include | Where-Object { $item.Name -notlike $_ }) { return }
            if ($Exclude | Where-Object { $item.Name -like $_ }) { return }

            Write-Output $item
        }

    }

    process
    {
        switch ($PSCmdlet.ParameterSetName)
        {
            'Path' { Read-AsarArchive -Path:$Path | ReadAsarFileInfo | FilterItems -File:$File -Directory:$Directory -Include:$Include -Exclude:$Exclude }
            'LiteralPath' { Read-AsarArchive -LiteralPath:$LiteralPath | ReadAsarFileInfo | FilterItems -File:$File -Directory:$Directory -Include:$Include -Exclude:$Exclude }
        }
    }
}
function Read-AsarArchive
{
    [CmdletBinding(DefaultParameterSetName = "Path")]
    param
    (
        # Specifies a path to one or more locations. Wildcards are permitted.
        [Parameter(ParameterSetName = "Path", Position = 0, Mandatory,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName,
            HelpMessage = "Path to one or more locations.")]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [string[]] $Path,

        # Specifies a path to one or more locations. Unlike the Path parameter, the value of the LiteralPath parameter is
        # used exactly as it is typed. No characters are interpreted as wildcards. If the path includes escape characters,
        # enclose it in single quotation marks. Single quotation marks tell Windows PowerShell not to interpret any
        # characters as escape sequences.
        [Parameter(
            ParameterSetName = "LiteralPath",
            Position = 0, Mandatory,
            ValueFromPipelineByPropertyName,
            HelpMessage = "Literal path to one or more locations.")]
        [Alias("PSPath")]
        [ValidateNotNullOrEmpty()]
        [string[]] $LiteralPath
    )

    begin
    {
        filter ReadAsarMetadata()
        {
            $reader = [BinaryReader]::new([File]::Open($_.FullName, [FileMode]::Open, [FileAccess]::Read, [FileShare]::Read))
            try
            {
                # format:
                #   UInt32 header_size_size             this is 4 always?
                #   UInt32 header_size                  the size of the "pickle" for the header.
                #   UInt32 string_data_size             indicates the size of the UTF-8 string data which is [UInt32 len, byte[] data, byte[] padding].
                #   UInt32 string_length                indicates the length in bytes of the UTF-8 string data.

                # first uint32 is... maybe the size of the header size to read? idk? just assume 4.
                $headerSizeSize = $reader.ReadUInt32()
                if ($headerSizeSize -ne 4)
                {
                    throw [InvalidDataException]::new("headerSizeSize is not 4 but ${headerSizeSize}")
                }

                $headerSize = $reader.ReadUInt32()
                $stringDataSize = $reader.ReadUInt32()

                if ($headerSize -ne $stringDataSize + 4)
                {
                    throw [InvalidDataException]::new(("headerSize {0:x8} and stringDataSize {1:x8} do not match.", $headerSize, $stringDataSize))
                }

                $stringSizeInBytes = $reader.ReadUInt32()
                return ConvertFrom-Json -InputObject $OutputEncoding.GetString($reader.ReadBytes($stringSizeInBytes))
            }
            finally
            {
                $reader.Close()
            }
        }
    }

    process
    {
        switch ($PSCmdlet.ParameterSetName)
        {
            'Path' { Get-Item -Path:$Path | ReadAsarMetadata }
            'LiteralPath' { Get-Item -LiteralPath:$LiteralPath | ReadAsarMetadata }
        }
    }
}