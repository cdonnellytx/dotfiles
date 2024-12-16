using namespace System
using namespace System.Collections.Generic
using namespace System.Diagnostics.CodeAnalysis
using namespace System.IO
using namespace System.Management.Automation
using namespace System.Runtime.InteropServices
using namespace System.Security

param
(
)

Set-StrictMode -Version Latest

enum VersionStatus
{
    Unknown = 0
    NotInstalled
    Available
    Installed
    Broken
}

class VersionInfo
{
    [semver] $Version
    [string] $Path
    [CommandInfo] $Command

    [VersionStatus] $Status

    [string] ToString()
    {
        return $this.Version.ToString()
    }
}

class SignatureVerifier
{
    [void] Verify([string] $path, [string] $signaturePath)
    {
        throw [NotImplementedException]::new()
    }
}

class GnuPGSignatureVerifier : SignatureVerifier
{
    [string] $Command = 'gpg'

    GnuPGSignatureVerifier([Hashtable] $config)
    {
        if ($config.Contains('command'))
        {
            $this.Command = $config['command']
        }
    }

    [void] Verify([string] $path, [string] $signaturePath)
    {
        # GnuPG uses the user's keyring, and any web-of-trust or local signatures or
        # anything else they have setup.  This is the crazy-powerful mode which is
        # overly confusing to newcomers.  We don't support it without the user creating
        # the file use-gnupg, optionally with directives in it.

        # Deliberately unquoted command, in case caller has something fancier in "use-gnupg".
        # Also, don't use batch mode.  If someone specifies GnuPG, let them deal with any prompting.
        $PSCmdlet.WriteVerbose("$($this.Command) --verify $signaturePath $path")
        & $this.Command --verify $signaturePath $path

        if (!$?)
        {
            throw [SecurityException]::new('PGP signature rejected by GnuPG');
        }
    }
}

class GpgvSignatureVerifier : SignatureVerifier
{
    [string] $Command = 'gpgv'
    [bool] $Trust = $false
    [TerraformVersionService] $service

    GpgvSignatureVerifier([TerraformVersionService] $service, [Hashtable] $config)
    {
        $this.Service = $service

        if ($config.Contains('command'))
        {
            $this.Command = $config['command']
        }

        if ($config.Contains('trust-tfenv'))
        {
            $this.Trust = !!$config['trust-tfenv']
        }
    }

    [void] Verify([string] $path, [string] $signaturePath)
    {
        # gpgv is a much simpler interface to verification, but does require that the
        # key have been downloaded and marked trusted.
        # We don't force the caller to trust the tfenv repo's copy of their key, they
        # have to choose to make that trust decision.
        if ($this.Trust)
        {
            & $this.Command --keyring "$($this.service.GetRootDirectoryPath())/share/hashicorp-keys.pgp" $signaturePath $path
        }
        else
        {
            & $this.Command $signaturePath $path
        }

        if (!$?)
        {
            throw [SecurityException]::new('PGP signature rejected')
        }
    }

}

class KeybaseSignatureVerifier : SignatureVerifier
{
    #           grep -Eq '^Logged in:[[:space:]]*yes' <("${keybase_bin}" status);
    #           keybase_logged_in="${?}";
    #           grep -Fq hashicorp <("${keybase_bin}" list-following);
    #           keybase_following_hc="${?}";

    #           if [[ "${keybase_logged_in}" -ne 0 || "${keybase_following_hc}" -ne 0 ]]; then
    #             log 'warn' 'Unable to verify OpenPGP signature unless logged into keybase and following hashicorp';
    #           else
    #             download_signature;
    #             "${keybase_bin}" pgp verify \
    #               -S hashicorp \
    #               -d "${download_tmp}/${shasumsSig}" \
    #               -i "${download_tmp}/${shasumsName}" \
    #               && log 'debug' 'SHA256SUMS signature matched' \
    #               || log 'error' 'SHA256SUMS signature does not match!';
    #           fi;

}

#
# Service
#
class TerraformVersionService
{
    static [string] $DefaultRoot = [Path]::Combine($HOME, '.tfenv')
    static [Uri] $DefaultRemoteUri = 'https://releases.hashicorp.com'

    [datetime] $Expiration

    # The Terraform-normalized default kernel name
    [string] $Kernel

    # The Terraform-normalized default architecture name
    [string] $Architecture

    TerraformVersionService()
    {
        $this.Kernel = if ($Global:PSVersionTable.PSVersion -lt '6.0') { 'windows' }
        elseif ([OperatingSystem]::IsWindows()) { 'windows' }
        elseif ([OperatingSystem]::IsMacOS()) { 'darwin' }
        elseif ([OperatingSystem]::IsLinux()) { 'linux' }
        elseif ([OperatingSystem]::IsFreeBSD()) { 'freebsd' }
        else
        {
            # Default to linux, like tfenv itself does.
            'linux'
        }

        $this.Architecture = switch ([RuntimeInformation]::OSArchitecture)
        {
            ([Architecture]::X64) { 'amd64' }
            ([Architecture]::X86) { '386' }
            ([Architecture]::Arm) { 'arm' }
            ([Architecture]::Arm64) { 'arm64' }
            # For everything else assume PowerShell and Terraform are using the same names.
            default { $_.ToString().ToLowerInvariant() }
        }
    }

    [string] GetArchitecture([semver] $version)
    {
        # Environment >> all
        if ($envArch = [Environment]::GetEnvironmentVariable('TFENV_ARCH'))
        {
            return $envArch
        }

        if ($this.Architecture -eq 'arm64')
        {
            # Special rules
            switch ($this.Kernel)
            {
                'linux'
                {
                    # There is no arm64 support for versions:
                    # < 0.11.15
                    # >= 0.12.0, < 0.12.30
                    # >= 0.13.0, < 0.13.5
                    if ($version.Major -eq 0)
                    {
                        switch ($version.Minor)
                        {
                            { $_ -lt 11 } { return 'amd64' }
                            11 { if ($version.Patch -lt 15) { return 'amd64' } }
                            12 { if ($version.Patch -lt 30) { return 'amd64' } }
                            13 { if ($version.Patch -lt 5) { return 'amd64' } }
                            # default: fall through
                        }
                    }

                    # Fall through
                }
                'darwin'
                {
                    # No Apple Silicon builds before 1.0.2
                    if ($Version -lt '1.0.2')
                    {
                        return 'amd64'
                    }

                    # Fall through
                }
            }
        }

        return $this.Architecture
    }

    <#
    .SYNOPSIS
    Get the download filename (aka "tarball name")
    #>
    [string] GetDownloadFilename([semver] $version)
    {
        $os = "{0}_{1}" -f $this.Kernel, $this.GetArchitecture($version)

        # Thanks for the inconsistency in 0.12-alpha, Hashicorp(!)
        if ($Version -like '0.12.0-alpha[3-9]')
        {
            return "terraform_${version}_terraform_${version}_${os}.zip"
        }
        else
        {
            return "terraform_${version}_${os}.zip"
        }
    }

    <#
    .SYNOPSIS
    Get the remote base URI.
    #>
    [Uri] GetRemoteUri()
    {
        if ($result = [Environment]::GetEnvironmentVariable('TFENV_REMOTE'))
        {
            return [Uri]::new($result)
        }

        return [TerraformVersionService]::DefaultRemoteUri
    }

    [Uri] GetVersionsUri()
    {
        return [Uri]::new($this.GetRemoteUri(), 'terraform/')
    }

    <#
    .SYNOPSIS
    Get the version base URI.
    #>
    [Uri] GetVersionUri([semver] $version)
    {
        return [Uri]::new($this.GetRemoteUri(), "terraform/${version}/")
    }

    hidden [Hashtable] ReadUseFile([string] $path)
    {
        # It's basically YAML
        $result = @{}
        foreach ($select in (Select-String -LiteralPath $path -Pattern '^(?<Key>[a-z][a-z\-]*): *(?<Value>\S.*)'))
        {
            foreach ($match in $select.Matches)
            {
                $result.Add($match.Groups[1].Value, $match.Groups[2].Value)
            }
        }
        return $result
    }

    <#
    .SYNOPSIS
    Get implementation to verify signature if verification mechanism (keybase, gpg, etc) is present
    #>
    [SignatureVerifier] GetSignatureVerifier()
    {
        $configDir = $this.GetConfigDirectoryPath()
        if ($paths = [Directory]::GetFiles($configDir, 'use-gnupg'))
        {
            return [GnuPGSignatureVerifier]::new($this.ReadUseFile($paths[0]))
        }

        if ($paths = [Directory]::GetFiles($configDir, 'use-gpgv'))
        {
            return [GpgvSignatureVerifier]::new($this, $this.ReadUseFile($paths[0]))
        }

        if ($keybaseCommand = Get-Command -Name 'keybase' -ErrorAction Ignore)
        {
            return [KeybaseSignatureVerifier]::new($keybaseCommand)
        }

        Write-Warning "Not instructed to use Local PGP (${configDir}/use-{gpgv,gnupg}) & No keybase install found, skipping OpenPGP signature verification";
        return $null
    }

    <#
    .SYNOPSIS
    Gets the path to the tfenv root directory (`$Env:TFENV_ROOT`).
    .NOTES
    Does not validate existence.
    #>
    [string] GetRootDirectoryPath()
    {
        if ($result = [System.Environment]::GetEnvironmentVariable('TFENV_ROOT'))
        {
            return $result
        }

        return [TerraformVersionService]::DefaultRoot
    }

    <#
    .SYNOPSIS
    Gets the path to the configuration directory (`$Env:TFENV_CONFIG_DIR`).
    .NOTES
    Does not validate existence.
    #>
    [string] GetConfigDirectoryPath()
    {
        if ($result = [System.Environment]::GetEnvironmentVariable('TFENV_CONFIG_DIR'))
        {
            return $result
        }

        return $this.GetRootDirectoryPath()
    }

    <#
    .SYNOPSIS
    Gets the path to the versions directory (`$Env:TFENV_CONFIG_DIR/versions`).
    .NOTES
    Does not validate existence.
    #>
    [string] GetVersionsDirectoryPath()
    {
        return [Path]::Combine($this.GetConfigDirectoryPath(), 'versions')
    }

    <#
    .SYNOPSIS
    Gets the directory object to the versions directory (`$Env:TFENV_CONFIG_DIR/versions`).
    .NOTES
    Does not validate existence.
    #>
    [DirectoryInfo] GetVersionsDirectoryInfo()
    {
        return [DirectoryInfo]::new($this.GetVersionsDirectoryPath())
    }

    <#
    .SYNOPSIS
    Gets the directory path for the specific version.
    .NOTES
    Does not validate existence.
    #>
    [string] GetVersionDirectoryPath([semver] $version)
    {
        return [Path]::Combine($this.GetVersionsDirectoryPath(), $version.ToString())
    }

    <#
    .SYNOPSIS
    Gets the directory object for the specific version.
    .NOTES
    Does not validate existence.
    #>
    [DirectoryInfo] GetVersionDirectoryInfo([semver] $version)
    {
        return [DirectoryInfo]::new($this.GetVersionDirectoryPath($version))
    }

    <#
    .SYNOPSIS
    Gets the path to the file for the currently used version.
    #>
    [string] GetUsedVersionFilePath()
    {
        return [Path]::Combine($this.GetConfigDirectoryPath(), 'version')
    }

    [semver] ReadVersion([string] $path)
    {
        [semver] $version = $null
        if ([File]::Exists($path) -and [semver]::TryParse([File]::ReadAllText($path), [ref] $version))
        {
            return $version
        }

        return $null
    }

    [semver] ReadVersionFromEnvironment([string] $name)
    {
        [semver] $version = $null
        if ([semver]::TryParse([Environment]::GetEnvironmentVariable($name), [ref] $version))
        {
            return $version
        }

        return $null
    }

    [void] WriteVersion([string] $path, [string] $version)
    {
        [File]::WriteAllText($path, $version)
    }

    hidden [string] FindLocalVersionFilePath([string] $path)
    {
        $PSCmdlet.WriteVerbose("Looking for a version file in ${path}")
        for ($dir = $path; $dir; $dir = [Path]::GetDirectoryName($dir))
        {
            $file = [Path]::Combine($dir, '.terraform-version')
            if ([File]::Exists($file))
            {
                $PSCmdlet.WriteVerbose("Found at ${file}")
                return $file
            }
            $PSCmdlet.WriteVerbose("Not found at ${file}")
        }

        $PSCmdlet.WriteVerbose("No version file found in ${path}")
        return $null
    }

    [SuppressMessageAttribute('PSAvoidGlobalVars', '', Target = 'HOME')]
    [string] GetCurrentVersionFilePath()
    {
        # Search for a .terraform-version file in the TFENV_DIR and up.
        # If there is no TFENV_DIR, try working directory.
        if ($tfenvDir = [Environment]::GetEnvironmentVariable('TFENV_DIR'))
        {
            if ($path = $this.FindLocalVersionFilePath($tfenvDir))
            {
                return $path
            }
        }
        elseif ($location = $PSCmdlet.CurrentProviderLocation('FileSystem'))
        {
            if ($path = $this.FindLocalVersionFilePath($location.Path))
            {
                return $path
            }
        }

        # Search for a .terraform-version file in the home directory and up.
        if ($path = $this.FindLocalVersionFilePath($global:HOME))
        {
            return $path
        }

        # Fallback to the used version
        $path = $this.GetUsedVersionFilePath()
        if ($path)
        {
            $PSCmdlet.WriteVerbose("No version file found in search paths.  Defaulting to TFENV_CONFIG_DIR: ${path}")
            return $path
        }

        $PSCmdlet.WriteVerbose("No version file found in search paths and no version file found in TFENV_CONFIG_DIR.")
        return $null
    }

    [semver] GetCurrentVersion()
    {
        $PSCmdlet.WriteVerbose("Getting version from GetCurrentVersion()")

        # Environment wins
        if ($version = $this.ReadVersionFromEnvironment('TFENV_TERRAFORM_VERSION'))
        {
            $PSCmdlet.WriteVerbose("TFENV_VERSION specified in TFENV_TERRAFORM_VERSION environment variable: ${version}")
            Add-Member -InputObject $version -MemberType NoteProperty -Name 'Source' -Value 'TFENV_TERRAFORM_VERSION'
            return $version
        }
        $PSCmdlet.WriteVerbose("We are not hardcoded by a TFENV_TERRAFORM_VERSION environment variable")

        $path = $this.GetCurrentVersionFilePath()
        $PSCmdlet.WriteVerbose("tfenv-version-file reported: ${path}")
        if ($version = $this.ReadVersion($path))
        {
            Add-Member -InputObject $version -MemberType NoteProperty -Name 'Source' -Value $path
            return $version
        }

        return $null
    }

    [VersionInfo] ReadVersionInfo([DirectoryInfo] $directory)
    {
        if (!$directory) { throw [ArgumentNullException]::new('directory') }

        [semver] $version = $directory.Name
        [VersionStatus] $Status = [VersionStatus]::Installed

        if (!$directory.Exists)
        {
            # It's not there.  We don't really know if it's a valid version or not.
            return [VersionInfo] @{
                Version = $version
                Path = $directory.FullName
                Status = [VersionStatus]::NotInstalled
            }
        }

        [CommandInfo] $Command = Get-Command -CommandType Application -Name ([Path]::Combine($directory.FullName, 'terraform')) #-ErrorAction Ignore
        if (!$Command)
        {
            # MSCRAP: On failure, Get-Command is returning a value that, for all intents and purposes, is null -- EXCEPT that it isn't,
            # AND cannot be cast to CommandInfo.
            $Status = [VersionStatus]::Broken
        }

        return [VersionInfo] @{
            Version = $version
            Path = $directory.FullName
            Command = $Command
            Status = $Status
        }
    }

    [IList[VersionInfo]] GetList()
    {
        $versionsDir = $this.GetVersionsDirectoryInfo()

        $result = [List[VersionInfo]]::new()
        if ($versionsDir.Exists)
        {
            foreach ($dir in $versionsDir.GetDirectories())
            {
                $result.Add($this.ReadVersionInfo($dir))
            }
        }

        return $result
    }

    [VersionInfo] GetExact([semver] $version)
    {
        $dir = $this.GetVersionDirectoryInfo($version)
        return $this.ReadVersionInfo($dir)
    }

    [IList[VersionInfo]] GetMatchingVersions([string] $pattern)
    {
        # don't necessarily like this... '^0.8' would match '0.81', '^1.0' would match '^100', etc.
        return $this.GetList() | Where-Object Version -CMatch $pattern
    }

    [VersionInfo] GetLatest()
    {
        $list = $this.GetList()
        if ($list.Count -eq 0)
        {
            throw [InvalidOperationException]::new("No terraform versions installed");
        }

        return $list | Sort-Object -Descending Version | Select-Object -First 1
    }

    [VersionInfo] GetCurrent()
    {
        $Version = $this.GetCurrentVersion()
        if ($Version)
        {
            return $this.Get($Version)
        }

        return $null
    }

    [void] Use([VersionInfo] $Version)
    {
        $this.WriteVersion($this.GetUsedVersionFilePath(), $Version.Version)
    }

    [bool] IsInstalled([semver] $version)
    {
        return $this.GetVersionDirectoryInfo($version).Exists
    }

    [VersionInfo] Get([string] $Version)
    {
        switch -wildcard ($Version)
        {
            'latest' { return $this.GetLatest() }
            'latest-allowed' { throw [NotImplementedException]::new($_) }
            'latest:*'
            {
                [VersionInfo[]] $versions = $this.GetMatchingVersions($_.Substring(7))
                if ($versions.Count -gt 0)
                {
                    return $versions | Sort-Object -Descending Version | Select-Object -First 1
                }
                break
            }
            'min-required' { throw [NotImplementedException]::new($_) }
            default
            {
                [semver] $exactVersion = $null;
                if ([semver]::TryParse($_, [ref] $exactVersion))
                {
                    return $this.GetExact($exactVersion)
                }
            }
        }

        Write-Error -Category ObjectNotFound -Message "Version '${Version}' was not found."
        return $null
    }
}

$Script:Service = [TerraformVersionService]::new()

#
# Cmdlets
#

function mktempdir
{
    # MSCRAP: why does dotnet STILL not have this as a primitve in TYOOL 2022
    $path = [Path]::GetTempFileName()
    [File]::Delete($path)

    $dir = [DirectoryInfo]::new($path)
    $dir.Create()
    return $dir
}

function Test-FileHash
{
    [CmdletBinding()]
    param
    (
        # The literal path to the source file.
        [Parameter(Mandatory, Position = 0)]
        [Alias("PSPath")]
        [ValidateNotNullOrEmpty()]
        [string] $LiteralPath,

        # The path to the check file.
        [Parameter(Mandatory, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string] $CheckPath,

        # Specifies the cryptographic hash function to use for computing the hash value of the contents of the specified file or stream.
        [string] $Algorithm = 'SHA256'
    )

    $fileName = [Path]::GetFileName($LiteralPath)

    $expectedHash = (Select-String -SimpleMatch -CaseSensitive -Pattern $fileName -LiteralPath $CheckPath).Line -Split '  ' | Select-Object -First 1
    $hash = (Get-FileHash -LiteralPath $LiteralPath -Algorithm $Algorithm).Hash

    return $expectedHash -ieq $hash
}

<#
.SYNOPSIS
Install a specific version of Terraform.

.DESCRIPTION
Installs the specified Terraform version into tfenv.

.PARAMETER WhatIf
Shows what would happen if the cmdlet runs. The cmdlet is not run.

.PARAMETER Confirm
Prompts you for confirmation before running the cmdlet.
#>
function Install-TerraformVersion
{
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    [OutputType([VersionInfo])]
    param
    (
        # The version of Terraform to install.
        # Can be a semver-compliant version or `latest`.
        [Parameter(Position = 0, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ $_ -eq 'latest' -or [semver] $_ })]
        [string[]] $Version,

        # Specifies that a prerelease version is acceptable.
        [switch] $Prerelease,

        # When set, returns a `VersionInfo` object representing the installed version.
        [switch] $PassThru,

        # When set, the version will be installed even if it already exists.
        [switch] $Force
    )

    begin
    {
        # Create a local temporary directory for downloads
        $downloadTmp = mktempdir
    }

    process
    {
        if (!$PSCmdlet.ShouldProcess("Versions: ${Version}", "Install Terraform"))
        {
            return
        }

        $signatureVerifier = $Service.GetSignatureVerifier()

        foreach ($item in $Version)
        {
            [semver] $ResolvedVersion = if ($Item -ne 'latest') { $Item }
            else
            {
                Find-TerraformVersion -Prerelease:$Prerelease | Sort-Object -Unique -Property Version -Descending | Select-Object -ExpandProperty Version -First 1
            }

            if (!$ResolvedVersion)
            {
                Write-Error -Category ObjectNotFound "Unable to find version '${Item}'"
                continue
            }

            $VersionInfo = $Service.Get($ResolvedVersion)

            if (!$Force -and $VersionInfo.Status -ne [VersionStatus]::NotInstalled)
            {
                Write-Error -Category ResourceExists "terraform v${ResolvedVersion} is already installed."
                continue
            }

            $tarballName = $Service.GetDownloadFilename($ResolvedVersion)

            $shasumsName = "terraform_${ResolvedVersion}_SHA256SUMS";
            $shasumsSigningKeyPostfix = ".72D7468F";
            $shasumsSigName = "${shasumsName}${shasumsSigningKeyPostfix}.sig";

            $versionUri = $Service.GetVersionUri($ResolvedVersion)

            Write-Information "Installing Terraform v${ResolvedVersion}";

            $tarballUri = [Uri]::new($versionUri, $tarballName)
            $tarballPath = [Path]::Combine($downloadTmp, $tarballName)
            Write-Information "Downloading release tarball from ${tarballUri}";
            Invoke-WebRequest -Uri $tarballUri -OutFile $tarballPath
            if ($?)
            {
                Write-Verbose "Release tarball downloaded successfully to ${tarballPath}";
            }
            else
            {
                Write-Error "Tarball download failed: ${tarballUri}"
                continue
            }

            $shasumsPath = [Path]::Combine($downloadTmp, $shasumsName)
            $shasumsUri = [Uri]::new($versionUri, $shasumsName)
            Write-Information "Downloading SHA hash file from ${shasumsUri}";
            Invoke-WebRequest -Uri $shasumsUri -OutFile $shasumsPath
            Write-Verbose "SHA hash file downloaded successfully to ${shasumsPath}";

            if ($signatureVerifier)
            {
                $shasumsSigUri = [Uri]::new($versionUri, $shasumsSigName)
                $shasumsSigPath = [Path]::Combine($downloadTmp, $shasumsSigName)
                Write-Information "Downloading SHA hash signature file from ${shasumsSigUri}";
                Invoke-WebRequest -Uri $shasumsSigUri -OutFile $shasumsSigPath
                Write-Verbose "SHA256SUMS signature file downloaded successfully to ${shasumsSigPath}";

                try
                {
                    $signatureVerifier.Verify($shasumsPath, $shasumsSigPath)
                }
                catch [SecurityException]
                {
                    Write-Error -Category SecurityError -Message $_
                    continue
                }
            }

            if (!(Test-FileHash -LiteralPath $tarballPath -CheckPath $shasumsPath -Algorithm SHA256))
            {
                Write-Error -Category SecurityError -Message "SHA256 hash does not match!"
                continue
            }

            $DestinationPath = $Service.GetVersionDirectoryInfo($ResolvedVersion)
            Expand-Archive -LiteralPath $tarballPath -DestinationPath $DestinationPath -Force:$Force
            if ($?)
            {
                Write-Information "Installation of terraform v${ResolvedVersion} successful. To make this your default version, run 'tfenv use ${ResolvedVersion}'"

                # It's not there.  We don't really know if it's a valid version or not.
                if ($PassThru)
                {
                    Write-Output $Service.ReadVersionInfo($DestinationPath)
                    continue
                }
            }
        }
    }

    end
    {
        $downloadTmp.Delete($true)
    }
}

<#
.SYNOPSIS
Uninstall a specific version of Terraform.

.DESCRIPTION
Uninstalls the specified Terraform version from tfenv.

.PARAMETER WhatIf
Shows what would happen if the cmdlet runs. The cmdlet is not run.

.PARAMETER Confirm
Prompts you for confirmation before running the cmdlet.
#>
function Uninstall-TerraformVersion
{
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param
    (
        # The version of Terraform to uninstall.
        # Can be a semver-compliant version or `latest`.
        [Parameter(Position = 0, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ $_ -eq 'latest' -or [semver] $_ })]
        [string[]] $Version
    )

    if (!$PSCmdlet.ShouldProcess("Versions: ${Version}", "Uninstall Terraform"))
    {
        return
    }

    $Version | ForEach-Object {
        if (($dir = $Service.GetVersionDirectoryInfo($_)) -and $dir.Exists)
        {
            return $dir
        }

        Write-Error -Category ObjectNotFound -Message "No versions matching $_ found in local"
    } | Remove-Item -Recurse
}

<#
.SYNOPSIS
Gets the list of remote versions.
.NOTES
Honors the `TFENV_REVERSE_REMOTE` environment variable.
#>
function Find-TerraformVersion
{
    [CmdletBinding()]
    [SuppressMessage('PSReviewUnusedParameter', 'Prerelease', Justification = 'It is used')]
    param
    (
        # Specifies that a prerelease version is acceptable.
        [switch] $Prerelease
    )

    # The content is HTML links.
    $result = Invoke-WebRequest -Uri $Service.GetVersionsUri()

    $Descending = ($Env:TFENV_REVERSE_REMOTE -ne '1')

    ($result.Links.Href | Select-String 'terraform/(\d[^/]*)').Matches | ForEach-Object { $_.Groups[1].Value } |
        Select-Object -Property @{ Name = 'Version'; Expression = { [semver] $_ } }, @{ Name = 'Installed'; Expression = { if ($Service.IsInstalled($_)) { 'Installed' } else { '' } } } |
        Sort-Object -Unique -Property Version -Descending:$Descending |
        Where-Object { $Prerelease -or !$_.Version.PreReleaseLabel }
}

function Invoke-Terraform
{
    [CmdletBinding()]
    param
    (
        [Parameter(ValueFromRemainingArguments)]
        [ValidateNotNullOrEmpty()]
        [string[]] $ArgumentList = @()
    )

    [CommandInfo] $cmd = if ($Current = $Script:Service.GetCurrent()) { $Current.Command } else { Get-Command -Name 'terraform' -CommandType Application -ErrorAction Stop }
    if ($VerbosePreference)
    {
        Write-Verbose -Message "Executing: ${cmd} ${ArgumentList}"
    }
    & $cmd $ArgumentList
}

<#
.SYNOPSIS
Switch the Terraform version currently in use.

.DESCRIPTION
Sets the current Terraform version.

.PARAMETER WhatIf
Shows what would happen if the cmdlet runs. The cmdlet is not run.

.PARAMETER Confirm
Prompts you for confirmation before running the cmdlet.
#>
function Use-TerraformVersion
{
    [CmdletBinding(DefaultParameterSetName = 'version', SupportsShouldProcess)]
    [OutputType([void])]
    [OutputType([VersionInfo])]
    param
    (
        # The version to set as current.
        # If not specified, the current will be determined and resolved.
        [Parameter(ParameterSetName = 'version', Position = 0)]
        [ValidateScript({ $_ -eq 'latest' -or [semver] $_ })]
        [string] $Version,

        # Specifies the latest installed as current.
        [Parameter(ParameterSetName = 'latest')]
        [switch] $Latest,

        # When set, returns a `VersionInfo` object representing the installed version.
        [Parameter()]
        [switch] $PassThru,

        # When true, the version will be downloaded and installed.
        # Default is based on whether the `TFENV_AUTO_INSTALL` variable is set to `true` or `false`;
        #
        # :warning: If not set, `TFENV_AUTO_INSTALL` is considered to be true.
        [Parameter()]
        [switch] $Force = ($Env:TFENV_AUTO_INSTALL -cin $null, 'true')
    )

    if ($Latest)
    {
        $Version = 'latest'
    }

    Write-Verbose "Version Requested: ${Version}"

    $VersionInfo = $Service.Get($Version)
    if (!$VersionInfo)
    {
        Write-Error -Category ObjectNotFound -Message "Version ${Version} was not found."
        return
    }

    switch ($VersionInfo.Status)
    {
        ([VersionStatus]::Installed)
        {
            # fall through
        }

        ([VersionStatus]::Broken)
        {
            Write-Error -Category InvalidResult -Message "Version directory for ${VersionInfo} is present, but the terraform binary is not! Manual intervention required."
            return
        }

        ([VersionStatus]::NotInstalled)
        {
            if (!$Force)
            {
                Write-Error -Category NotInstalled -Message "Version $VersionInfo ($($VersionInfo.Path)) is not installed.  Either specify -Force to install, or install via the 'Install-TerraformVersion' cmdlet."
                return
            }

            $NewVersionInfo = Install-TerraformVersion -Version $VersionInfo.Version -PassThru
            if (!$WhatIfPreference)
            {
                if (!$NewVersionInfo)
                {
                    Write-Error -Category NotInstalled -Message "Installing version matching ${VersionInfo} failed"
                    return
                }

                $VersionInfo = $NewVersionInfo
            }

            # Fall through
        }

        default
        {
            Write-Error -Category InvalidResult -Message "Version ${VersionInfo} was found but is in a $($VersionInfo.Status.ToString().ToLowerInvariant()) state."
            return
        }
    }

    if (!$PSCmdlet.ShouldProcess("Version: ${VersionInfo}", "Use Terraform"))
    {
        return
    }

    $Service.Use($VersionInfo)

    if ($PassThru)
    {
        return $VersionInfo
    }
}

class VersionListItem
{
    [semver] $Version
    [string] $Current
    [Alias('PSPath')]
    [string] $Path
    [VersionStatus] $Status
}

<#
.SYNOPSIS
Gets the current version.
#>
function Get-CurrentTerraformVersion
{
    [CmdletBinding()]
    [OutputType([VersionInfo])]
    param()

    return $Script:Service.GetCurrent()
}

<#
.SYNOPSIS
List all installed Terraform versions.

.DESCRIPTION
Gets a list all installed Terraform versions, including the current state of the install.
#>
function Get-TerraformVersion
{
    [CmdletBinding()]
    [OutputType([VersionInfo])]
    param()

    $CurrentVersion = $Script:Service.GetCurrentVersion()

    Write-Verbose 'Listing versions'

    $Script:Service.GetList() | Sort-Object Version -Descending | ForEach-Object {
        [VersionListItem] @{
            Version = $_.Version
            Current = if ($_.Version -eq $CurrentVersion) { $CurrentVersion.Source }
            Path = $_.Path
            Status = $_.Status
        }
    }
}

<#
.SYNOPSIS
Pins the current active Terraform version to `$pwd/.terraform-version`.

.PARAMETER WhatIf
Shows what would happen if the cmdlet runs. The cmdlet is not run.

.PARAMETER Confirm
Prompts you for confirmation before running the cmdlet.
#>
function Lock-TerraformVersion
{
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()

    if ($version = $Service.GetCurrentVersion())
    {
        $dir = $PSCmdlet.CurrentProviderLocation('FileSystem').Path
        $file = [Path]::Combine($dir, '.terraform-version')
        if ($PSCmdlet.ShouldProcess("Version: ${version}, Path: ${dir}", "Pin Terraform version"))
        {
            $Service.WriteVersion($path, $version)
            Write-Information "Pinned version by writing ${version} to ${file}"
        }
    }
}

<#
.SYNOPSIS
Invokes the specified tfenv command.

.DESCRIPTION
Invokes the specified tfenv command.

Commands:

    install       Install-TerraformVersion      Install a specific version of Terraform
    use           Use-TerraformVersion          Switch a version to use
    uninstall     Uninstall-TerraformVersion    Uninstall a specific version of Terraform
    list          Get-TerraformVersion          List all installed versions
    list-remote   Find-TerraformVersion         List all installable versions
    version-name  Get-CurrentTerraformVersion   Print current version
    init                                        Update environment to use tfenv correctly.
    pin           Lock-TerraformVersion         Write the current active version to ./.terraform-version

.PARAMETER WhatIf
Shows what would happen if the cmdlet runs. The cmdlet is not run.

.PARAMETER Confirm
Prompts you for confirmation before running the cmdlet.
#>
function Invoke-TFEnv
{
    [SuppressMessageAttribute("PSShouldProcess", "")] # Because PSScriptAnalyzer team refuses to listen to reason. See bugs:  #194 #283 #521 #608
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        # The name of the command to invoke.
        [Parameter(Position = 0, Mandatory)]
        [ValidateSet('install', 'use', 'uninstall', 'list', 'list-remote', 'version-name', 'init', 'pin')]
        [string] $Command,

        # The list of arguments to pass to the command.
        [Parameter(ValueFromRemainingArguments)]
        [ValidateNotNullOrEmpty()]
        [string[]] $ArgumentList = @()
    )

    Write-Verbose "tfenv argument is: ${Command}"

    switch ($Command)
    {
        'use' { Use-TerraformVersion @ArgumentList }
        'list' { Get-TerraformVersion @ArgumentList }
        'list-remote' { Find-TerraformVersion @ArgumentList }
        'version-name' { Get-CurrentTerraformVersion @ArgumentList }
        'install' { Install-TerraformVersion @ArgumentList }
        'uninstall' { Uninstall-TerraformVersion @ArgumentList }
        'pin' { Lock-TerraformVersion @ArgumentList }
        'init'
        {
            # Does nothing.  This is simply for compatibility reasons; init is done by importing the module.
        }
        default
        {
            Write-Error -Category ObjectNotFound "Command '${Command}' not found."
        }
    }
}

# General command aliases.
Set-Alias -Name 'tfenv' -Value 'Invoke-TFEnv'
Set-Alias -Name 'terraform' -Value 'Invoke-Terraform'

# Specific command aliases.
Set-Alias -Name 'Pin-TerraformVersion' -Value 'Lock-TerraformVersion'
Set-Alias -Name 'Switch-TerraformVersion' -Value 'Use-TerraformVersion'