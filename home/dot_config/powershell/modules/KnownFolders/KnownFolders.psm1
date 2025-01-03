using namespace System.Collections.Generic
using namespace System.Management.Automation

Set-StrictMode -Version Latest

if ($PSVersionTable.PSVersion.Major -ge 6 -and !$IsWindows)
{
    throw [System.PlatformNotSupportedException]::new("KnownFolders is limited to Windows.")
}

# A list of "known" known folder GUIDs, by name, from the Windows SDK.
$SdkByName = @{
    # Synchronized with Windows SDK 10.0.22621.0 KnownFolders.h
    'AccountPictures' = '008ca0b1-55b4-4c56-b8a8-4de4b299d3be'
    'AddNewPrograms' = 'de61d971-5ebc-4f02-a3a9-6c82895e5c04'
    'AdminTools' = '724ef170-a42d-4fef-9f26-b60e846fba4f'
    'AllAppMods' = '7ad67899-66af-43ba-9156-6aad42e6c596'
    'AppCaptures' = 'edc0fe71-98d8-4f4a-b920-c8dc133cb165'
    'AppDataDesktop' = 'b2c5e279-7add-439f-b28c-c41fe1bbf672'
    'AppDataDocuments' = '7be16610-1f7f-44ac-bff0-83e15f2ffca1'
    'AppDataFavorites' = '7cfbefbc-de1f-45aa-b843-a542ac536cc9'
    'AppDataProgramData' = '559d40a3-a036-40fa-af61-84cb430a4d34'
    'ApplicationShortcuts' = 'a3918781-e5f2-4890-b3d9-a7e54332328c'
    'AppsFolder' = '1e87508d-89c2-42f0-8a7e-645a0f50ca58'
    'AppUpdates' = 'a305ce99-f527-492b-8b1a-7e76fa98d6e4'
    'CameraRoll' = 'ab5fb87b-7ce2-4f83-915d-550846c9537b'
    'CameraRollLibrary' = '2b20df75-1eda-4039-8097-38798227d5b7'
    'CDBurning' = '9e52ab10-f80d-49df-acb8-4330f5687855'
    'ChangeRemovePrograms' = 'df7266ac-9274-4867-8d55-3bd661de872d'
    'CommonAdminTools' = 'd0384e7d-bac3-4797-8f14-cba229b392b5'
    'CommonOEMLinks' = 'c1bae2d0-10df-4334-bedd-7aa20b227a9d'
    'CommonPrograms' = '0139d44e-6afe-49f2-8690-3dafcae6ffb8'
    'CommonStartMenu' = 'a4115719-d62e-491d-aa7c-e74b8be3b067'
    'CommonStartMenuPlaces' = 'a440879f-87a0-4f7d-b700-0207b966194a'
    'CommonStartup' = '82a5ea35-d9cd-47c5-9629-e15d2f714e6e'
    'CommonTemplates' = 'b94237e7-57ac-4347-9151-b08c6c32d1f7'
    'ComputerFolder' = '0ac0837c-bbf8-452a-850d-79d08e667ca7'
    'ConflictFolder' = '4bfefb45-347d-4006-a5be-ac0cb0567192'
    'ConnectionsFolder' = '6f0cd92b-2e97-45d1-88ff-b0d186b8dedd'
    'Contacts' = '56784854-c6cb-462b-8169-88e350acb882'
    'ControlPanelFolder' = '82a74aeb-aeb4-465c-a014-d097ee346d63'
    'Cookies' = '2b0f765d-c0e9-4171-908e-08a611b84ff6'
    'CurrentAppMods' = '3db40b20-2a30-4dbe-917e-771dd21dd099'
    'Desktop' = 'b4bfcc3a-db2c-424c-b029-7fe99a87c641'
    'DevelopmentFiles' = 'dbe8e08e-3053-4bbc-b183-2a7b2b191e59'
    'Device' = '1c2ac1dc-4358-4b6c-9733-af21156576f0'
    'DeviceMetadataStore' = '5ce4a5e9-e4eb-479d-b89f-130c02886155'
    'Documents' = 'fdd39ad0-238f-46af-adb4-6c85480369c7'
    'DocumentsLibrary' = '7b0db17d-9cd2-4a93-9733-46cc89022e7c'
    'Downloads' = '374de290-123f-4565-9164-39c4925e467b'
    'Favorites' = '1777f761-68ad-4d8a-87bd-30b759fa33dd'
    'Fonts' = 'fd228cb7-ae11-4ae3-864c-16f3910ab8fe'
    'GameTasks' = '054fae61-4dd8-4787-80b6-090220c4b700'
    'History' = 'd9dc8a3b-b784-432e-a781-5a1130a75963'
    'HomeGroup' = '52528a6b-b9e3-4add-b60d-588c2dba842d'
    'HomeGroupCurrentUser' = '9b74b6a3-0dfd-4f11-9e78-5f7800f2e772'
    'ImplicitAppShortcuts' = 'bcb5256f-79f6-4cee-b725-dc34e402fd46'
    'InternetCache' = '352481e8-33be-4251-ba85-6007caedcf9d'
    'InternetFolder' = '4d9f7874-4e0c-4904-967b-40b0d20c3e4b'
    'Libraries' = '1b3ea5dc-b587-4786-b4ef-bd1dc332aeae'
    'Links' = 'bfb9d5e0-c6a9-404c-b2b2-ae6db6af4968'
    'LocalAppData' = 'f1b32785-6fba-4fcf-9d55-7b8e7f157091'
    'LocalAppDataLow' = 'a520a1a4-1780-4ff6-bd18-167343c5af16'
    'LocalDocuments' = 'f42ee2d3-909f-4907-8871-4c22fc0bf756'
    'LocalDownloads' = '7d83ee9b-2244-4e70-b1f5-5393042af1e4'
    'LocalizedResourcesDir' = '2a00375e-224c-49de-b8d1-440df7ef3ddc'
    'LocalMusic' = 'a0c69a99-21c8-4671-8703-7934162fcf1d'
    'LocalStorage' = 'b3eb08d3-a1f3-496b-865a-42b536cda0ec'
    'LocalVideos' = '35286a68-3c57-41a1-bbb1-0eae73d76c95'
    'Music' = '4bd8d571-6d19-48d3-be97-422220080e43'
    'MusicLibrary' = '2112ab0a-c86a-4ffe-a368-0de96e47012e'
    'NetHood' = 'c5abbf53-e17f-4121-8900-86626fc2c973'
    'NetworkFolder' = 'd20beec4-5ca8-4905-ae3b-bf251ea09b53'
    'Objects3D' = '31c0dd25-9439-4f12-bf41-7ff4eda38722'
    'OriginalImages' = '2c36c0aa-5812-4b87-bfd0-4cd0dfb19b39'
    'PhotoAlbums' = '69d2cf90-fc33-4fb7-9a0c-ebb0f0fcb43c'
    'Pictures' = '33e28130-4e1e-4676-835a-98395c3bc3bb'
    'PicturesLibrary' = 'a990ae9f-a03b-4e80-94bc-9912d7504104'
    'Playlists' = 'de92c1c7-837f-4f69-a3bb-86e631204a23'
    'PrintersFolder' = '76fc4e2d-d6ad-4519-a663-37bd56068185'
    'PrintHood' = '9274bd8d-cfd1-41c3-b35e-b13f55a758f4'
    'Profile' = '5e6c858f-0e22-4760-9afe-ea3317b67173'
    'ProgramData' = '62ab5d82-fdc1-4dc3-a9dd-070d1d495d97'
    'ProgramFiles' = '905e63b6-c1bf-494e-b29c-65b732d3d21a'
    'ProgramFilesCommon' = 'f7f1ed05-9f6d-47a2-aaae-29d317c6f066'
    'ProgramFilesCommonX64' = '6365d5a7-0f0d-45e5-87f6-0da56b6a4f7d'
    'ProgramFilesCommonX86' = 'de974d24-d9c6-4d3e-bf91-f4455120b917'
    'ProgramFilesX64' = '6d809377-6af0-444b-8957-a3773f02200e'
    'ProgramFilesX86' = '7c5a40ef-a0fb-4bfc-874a-c0f2e0b9fa8e'
    'Programs' = 'a77f5d77-2e2b-44c3-a6a2-aba601054a51'
    'Public' = 'dfdf76a2-c82a-4d63-906a-5644ac457385'
    'PublicDesktop' = 'c4aa340d-f20f-4863-afef-f87ef2e6ba25'
    'PublicDocuments' = 'ed4824af-dce4-45a8-81e2-fc7965083634'
    'PublicDownloads' = '3d644c9b-1fb8-4f30-9b45-f670235f79c0'
    'PublicGameTasks' = 'debf2536-e1a8-4c59-b6a2-414586476aea'
    'PublicLibraries' = '48daf80b-e6cf-4f4e-b800-0e69d84ee384'
    'PublicMusic' = '3214fab5-9757-4298-bb61-92a9deaa44ff'
    'PublicPictures' = 'b6ebfb86-6907-413c-9af7-4fc2abf07cc5'
    'PublicRingtones' = 'e555ab60-153b-4d17-9f04-a5fe99fc15ec'
    'PublicUserTiles' = '0482af6c-08f1-4c34-8c90-e17ec98b1e17'
    'PublicVideos' = '2400183a-6185-49fb-a2d8-4a392a602ba3'
    'QuickLaunch' = '52a4f021-7b75-48a9-9f6b-4b87a210bc8f'
    'Recent' = 'ae50c081-ebd2-438a-8655-8a092e34987a'
    'RecordedCalls' = '2f8b40c2-83ed-48ee-b383-a1f157ec6f9a'
    'RecordedTVLibrary' = '1a6fdba2-f42d-4358-a798-b74d745926c5'
    'RecycleBinFolder' = 'b7534046-3ecb-4c18-be4e-64cd4cb7d6ac'
    'ResourceDir' = '8ad10c31-2adb-4296-a8f7-e4701232c972'
    'RetailDemo' = '12d4c69e-24ad-4923-be19-31321c43a767'
    'Ringtones' = 'c870044b-f49e-4126-a9c3-b52a1ff411e8'
    'RoamedTileImages' = 'aaa8d5a5-f1d6-4259-baa8-78e7ef60835e'
    'RoamingAppData' = '3eb685db-65f9-4cf6-a03a-e3ef65729f3d'
    'RoamingTiles' = '00bcfc5a-ed94-4e48-96a1-3f6217f21990'
    'SampleMusic' = 'b250c668-f57d-4ee1-a63c-290ee7d1aa1f'
    'SamplePictures' = 'c4900540-2379-4c75-844b-64e6faf8716b'
    'SamplePlaylists' = '15ca69b3-30ee-49c1-ace1-6b5ec372afb5'
    'SampleVideos' = '859ead94-2e85-48ad-a71a-0969cb56a6cd'
    'SavedGames' = '4c5c32ff-bb9d-43b0-b5b4-2d72e54eaaa4'
    'SavedPictures' = '3b193882-d3ad-4eab-965a-69829d1fb59f'
    'SavedPicturesLibrary' = 'e25b5812-be88-4bd9-94b0-29233477b6c3'
    'SavedSearches' = '7d1d3a04-debb-4115-95cf-2f29da2920da'
    'Screenshots' = 'b7bede81-df94-4682-a7d8-57a52620b86f'
    'SEARCH_CSC' = 'ee32e446-31ca-4aba-814f-a5ebd2fd6d5e'
    'SEARCH_MAPI' = '98ec0e18-2098-4d44-8644-66979315a281'
    'SearchHistory' = '0d4c3db6-03a3-462f-a0e6-08924c41b5d4'
    'SearchHome' = '190337d1-b8ca-4121-a639-6d472d16972a'
    'SearchTemplates' = '7e636bfe-dfa9-4d5e-b456-d7b39851d8a9'
    'SendTo' = '8983036c-27c0-404b-8f08-102d10dcfd74'
    'SidebarDefaultParts' = '7b396e54-9ec5-4300-be0a-2482ebae1a26'
    'SidebarParts' = 'a75d362e-50fc-4fb7-ac2c-a8beaa314493'
    'SkyDriveCameraRoll' = '767e6811-49cb-4273-87c2-20f355e1085b'
    'SkyDriveDocuments' = '24d89e24-2f19-4534-9dde-6a6671fbb8fe'
    'SkyDriveMusic' = 'c3f2459e-80d6-45dc-bfef-1f769f2be730'
    'SkyDrivePictures' = '339719b5-8c47-4894-94c2-d8f77add44a6'
    'StartMenu' = '625b53c3-ab48-4ec1-ba1f-a1ef4146fc19'
    'StartMenuAllPrograms' = 'f26305ef-6948-40b9-b255-81453d09c785'
    'Startup' = 'b97d20bb-f46a-4c97-ba10-5e3608430854'
    'SyncManagerFolder' = '43668bf8-c14e-49b2-97c9-747784d784b7'
    'SyncResultsFolder' = '289a9a43-be44-4057-a41b-587a76d7e7f9'
    'SyncSetupFolder' = '0f214138-b1d3-4a90-bba9-27cbc0c5389a'
    'System' = '1ac14e77-02e7-4e5d-b744-2eb1ae5198b7'
    'SystemX86' = 'd65231b0-b2f1-4857-a4ce-a8e7c6ea7d27'
    'Templates' = 'a63293e8-664e-48db-a079-df759e0509f7'
    'UserPinned' = '9e3995ab-1f9c-4f13-b827-48b24b6c7174'
    'UserProfiles' = '0762d272-c50a-4bb0-a382-697dcd729b80'
    'UserProgramFiles' = '5cd7aee2-2219-4a67-b85d-6c9ce15660cb'
    'UserProgramFilesCommon' = 'bcbd3057-ca5c-4622-b42d-bc56db0ae516'
    'UsersFiles' = 'f3ce0f7c-4901-4acc-8648-d5d44b04ef8f'
    'UsersLibraries' = 'a302545d-deff-464b-abe8-61c8648d939b'
    'Videos' = '18989b1d-99b5-455b-841c-ab7c74e4ddfc'
    'VideosLibrary' = '491e922f-5643-4af4-a7eb-4e7a138d8174'
    'Windows' = 'f38bf404-1d43-42f2-9305-67de0b28fc23'
}

[Dictionary[string, Guid]] $_FoldersByName = $null
[Dictionary[Guid, string[]]] $_FoldersByGuid = $null

function Build-FoldersByName
{
    [CmdletBinding()]
    [OutputType([Dictionary[string, Guid]])]
    param()

    # Clone the predefined known list
    $foldersByName = [Dictionary[string, Guid]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $SdkByName.GetEnumerator() | ForEach-Object {
        $value = $_.Value
        $foldersByName.Add($_.Name, $value)
        switch -regex ($_.Name)
        {
            # Synonyms: PublicXXX, CommonXXX
            '^Common(\w+)'
            {
                $foldersByName.Add("Public$($Matches[1])", $value)
            }
            '^Public(\w+)'
            {
                $foldersByName.Add("Common$($Matches[1])", $value)
            }
        }
    }

    # Now get all values from the registry.
    Get-ChildItem -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions' | ForEach-Object {
        $name = $_.GetValue("Name") -creplace ' ', ''
        if ($foldersByName.ContainsKey($name)) { return }

        $value = [Guid] $_.PSChildName
        $foldersByName.Add($name, $value)

        if ($name.IndexOf(' ') -ge 0)
        {
            $foldersByName.Add(($name -creplace ' ', ''), $value)
        }
    }

    return $foldersByName
}

function Get-FoldersByName
{
    [CmdletBinding()]
    [OutputType([Dictionary[string, Guid]])]
    param()

    if ($null -eq $_FoldersByName)
    {
        $script:_FoldersByName = Build-FoldersByName -ErrorAction Stop
    }

    return $_FoldersByName
}

function Build-FoldersByGuid
{
    [CmdletBinding()]
    [OutputType([Dictionary[Guid, string[]]])]
    param()

    $foldersByName = Get-FoldersByName -ErrorAction Stop
    $foldersByGuid = [Dictionary[Guid, string[]]]::new()
    $foldersByName.GetEnumerator() | Group-Object -Property { [Guid] $_.Value } | ForEach-Object {
        $foldersByGuid.Add($_.Name, [string[]] $_.Group.Key)
    }

    return $foldersByGuid
}

function Get-FoldersByGuid
{
    [CmdletBinding()]
    [OutputType([Dictionary[Guid, string[]]])]
    param()

    if ($null -eq $_FoldersByGuid)
    {
        $script:_FoldersByGuid = Build-FoldersByGuid -ErrorAction Stop
    }

    return $_FoldersByGuid
}

$KnownFolders = Add-Type -ErrorAction Stop -PassThru -Namespace 'CDonnelly' -Name 'KnownFolders' `
    -UsingNamespace 'System.ComponentModel', 'System.IO' `
    -MemberDefinition @"
    [DllImport("shell32.dll")]
    private static extern uint SHGetKnownFolderPath(
        [MarshalAs(UnmanagedType.LPStruct)] Guid rfid,
        uint dwFlags,
        IntPtr hToken,
        out IntPtr pszPath);

    public static bool TryGetKnownFolderPath(Guid rfid, out string path)
    {
        switch (SHGetKnownFolderPath(rfid, 0, IntPtr.Zero, out IntPtr pszPath))
        {
            case 0:
                // we're good
                path = Marshal.PtrToStringUni(pszPath);
                Marshal.FreeCoTaskMem(pszPath);
                return true;

            default:
                path = null;
                return false;
        }
    }

    public static string GetKnownFolderPath(Guid rfid)
    {
        IntPtr pszPath;
        uint result = SHGetKnownFolderPath(rfid, 0, IntPtr.Zero, out pszPath);
        switch (result)
        {
            case 0:
                // we're good
                string path = Marshal.PtrToStringUni(pszPath);
                Marshal.FreeCoTaskMem(pszPath);
                return path;

            // Error codes where code is most likely NOT registered.
            case 0x80070002: // FileNotFound
                throw new FileNotFoundException("File not found", rfid.ToString());
            case 0x80070003: // PathNotFound
                throw new FileNotFoundException("Path not found", rfid.ToString());
            case 0x80004005: // Unspecified error
                throw new InvalidOperationException("Unspecified error");

            default:
                throw new Win32Exception((int)result);
        }
    }

    [DllImport("shell32.dll")]
    private static extern uint SHSetKnownFolderPath(
        ref Guid rfid,
        uint dwFlags,
        IntPtr hToken,
        [MarshalAs(UnmanagedType.LPWStr)] string pszPath
    );

    public static void SetKnownFolderPath(Guid rfid, string path)
    {
        uint result = SHSetKnownFolderPath(ref rfid, 0, IntPtr.Zero, path);
        switch (result)
        {
            case 0:
                // we're good
                break;
            default:
                throw new Win32Exception((int)result);
        }
    }
"@

function Resolve-KnownFolderId
{
    [CmdletBinding(SupportsShouldProcess = $false)]
    [OutputType([Guid])]
    param
    (
        [Parameter(Position = 0, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name
    )

    [Guid] $result = [Guid]::Empty
    $foldersByName = Get-FoldersByName
    if ($foldersByName.TryGetValue($Name, [ref] $result))
    {
        return $result
    }

    if ([Guid]::TryParse($Name, [ref] $result))
    {
        return $result
    }

    throw [ArgumentOutOfRangeException]::new('KnownFolder', $Name, "No such known folder.")
}

class KnownFolder
{
    [Guid] $Id
    [string] $Name
    [string] $Path
}

<#
.SYNOPSIS
    Gets a known folder's information.
.PARAMETER Name
    The name of the known folder.
.PARAMETER AsObject
    Whether an object is returned.  If multiple names are specified, this is always true.
.OUTPUTS
    The path (if AsObject is false); an object (if AsObject is true).
#>
function Get-KnownFolder
{
    [CmdletBinding(DefaultParameterSetName = "Name")]
    param
    (
        [Parameter(Mandatory, Position = 0, ParameterSetName = "Name")]
        [ValidateNotNullOrEmpty()]
        [string[]] $Name,

        [Parameter(ParameterSetName = "Name")]
        [switch] $AsObject,

        [Parameter(ParameterSetName = "List")]
        [switch] $List
    )

    switch ($PSCmdlet.ParameterSetName)
    {
        "List"
        {
            if (!$List)
            {
                Write-Error -Category InvalidArgument -Message "List parameter is required."
                return
            }

            Get-ChildItem -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions' | Get-ItemProperty -Name 'Name', 'ParentFolder' -ErrorAction Ignore | Select-Object PSChildName, Name, ParentFolder | ForEach-Object {
                $item = $_
                $KnownFolderId = [Guid] $item.PSChildName

                try
                {
                    [string] $Path = $null
                    $KnownFolders::TryGetKnownFolderPath($KnownFolderId, [ref] $Path) > $null
                    return [KnownFolder] @{
                        Name = $_.Name
                        Path = $Path
                        Id = $KnownFolderId
                    }
                }
                catch
                {
                    Write-Error -Category ObjectNotFound -Message "For item '$($item.Name), rfid='${KnownFolderId}': $($_.Exception.Message)" -Exception $_.Exception
                }
            } | Sort-Object -Property Name
        }
        "Name"
        {
            $AsObject = $AsObject -or $Name.Length -gt 1

            # asking for named folder(s).
            $foldersByGuid = Get-FoldersByGuid
            $Name | ForEach-Object {
                [string] $itemName = $_
                [Guid] $KnownFolderId = [Guid]::Empty
                if ([Guid]::TryParse($_, [ref] $KnownFolderId))
                {
                    $itemName = $foldersByGuid[$KnownFolderId][0]
                }
                else
                {
                    $itemName = $_
                    $KnownFolderId = Resolve-KnownFolderId -Name $itemName
                }

                Write-Debug "'$_' => Id: ${KnownFolderId}, Name: ${itemName}"

                try
                {
                    $path = $KnownFolders::GetKnownFolderPath($KnownFolderId);
                    if ($AsObject)
                    {
                        return [KnownFolder] @{
                            Name = $itemName
                            Path = $Path
                            Id = $KnownFolderId
                        }
                    }
                    else
                    {
                        return $path
                    }
                }
                catch
                {
                    Write-Error -Category ObjectNotFound -Message "For item '${itemName}', rfid='${KnownFolderId}'" -Exception $_.Exception
                    return
                }

            }
        }
    }
}

<#
.SYNOPSIS
    Sets a known folder's path using SHSetKnownFolderPath.
.PARAMETER Folder
    The known folder whose path to set.
.PARAMETER Path
    The path.
#>
function Set-KnownFolder
{
    [CmdletBinding(SupportsShouldProcess = $true)]
    param
    (
        [Parameter(Position = 0, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias('KnownFolder')]
        [string] $Name,

        [Parameter(Position = 1, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias('Value')]
        [string] $Path
    )

    $rfid = Resolve-KnownFolderId -Name $Name
    # Validate the path
    $item = Get-Item -Path $Path -ErrorAction Stop
    if (!($item.Attributes -band 'Directory'))
    {
        Write-Error -Category InvalidOperation -Message "Unable to set known folder because it is not a directory: '$($item.FullName)'."
        return
    }

    if ($PSCmdlet.ShouldProcess("Known folder: '$Name' Path: '$Path'", "Set known folder path"))
    {
        $rfid = Resolve-KnownFolderId $Name
        try
        {
            $KnownFolders::SetKnownFolderPath($rfid, $item.FullName)
        }
        catch
        {
            Write-Error -Category InvalidOperation -Message "For folder '${Name}', path='${Path}' => '$($item.FullName)', rfid='${rfid}': $($_.Exception.InnerException.Message)"
            return
        }
    }
}

Microsoft.PowerShell.Core\Register-ArgumentCompleter -CommandName 'Get-KnownFolder', 'Set-KnownFolder' -ParameterName 'Name' -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    Write-Verbose "argcomplete $commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters"

    (Get-FoldersByName).Keys | Where-Object { $_.StartsWith($wordToComplete, [StringComparison]::OrdinalIgnoreCase) } | Sort-Object
}



# Only export these
Export-ModuleMember `
    -Function @(
    'Get-KnownFolder',
    'Set-KnownFolder'
)

