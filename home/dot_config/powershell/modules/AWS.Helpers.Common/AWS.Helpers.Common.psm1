#requires -Module AWS.Tools.Common
using namespace System.Collections.Generic
using namespace System.Diagnostics.CodeAnalysis
using namespace System.Management.Automation
using namespace Amazon.Runtime

<#
.SYNOPSIS
Gets the current AWS credentials based on environment variables.

Order of precedence:
- AWS_ACCESS_KEY_ID environment variable
- AWS_PROFILE environment variable (if name matches a profile in ~/.aws/credentials)

.NOTES
There's got to be a way to get these from cmdlets.
#>
function Get-AWSFallbackCredential
{
    [CmdletBinding()]
    [OutputType([Amazon.Runtime.AWSCredentials])]
    param()

    # Read AWS credentials out from the "fallback" factory.
    # This appears to bootstrap from environment depending on what's set (AWS_PROFILE, AWS_ACCESS_KEY_ID).
    Write-Verbose "Reading AWS credentials from fallback factory..."
    [FallbackCredentialsFactory]::Reset()
    return [FallbackCredentialsFactory]::GetCredentials()
}

function Clear-AWSEnvironment
{
    [OutputType([void])]
    param
    (
    )

    Remove-Item -ErrorAction Ignore -LiteralPath `
        Env:AWS_PROFILE,
        Env:AWS_ACCESS_KEY_ID,
        Env:AWS_SECRET_ACCESS_KEY,
        Env:AWS_REGION,
        Env:AWS_SESSION_TOKEN
}

<#
.SYNOPSIS
Starts an AWS session by loading it.
#>
function Start-AWSSession
{
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param
    (
        # The user-defined name of an AWS credentials or SAML-based role profile containing credential information.
        # The profile is expected to be found in the secure credential file shared with the AWS SDK for .NET and AWS Toolkit for Visual Studio.
        # You can also specify the name of a profile stored in the .ini-format credential file used with the AWS CLI and other AWS SDKs.
        [Parameter(Position = 0, Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string] $ProfileName,

        # Used to specify the name and location of the ini-format credential file (shared with the AWS CLI and other AWS SDKs).
        # If this optional parameter is omitted this cmdlet will search the encrypted credential file used by the AWS SDK for .NET and AWS Toolkit for Visual Studio first. If the profile is not found then the cmdlet will search in the ini-format credential file at the default location: (user's home directory)\.aws\credentials.
        # If this parameter is specified then this cmdlet will only search the ini-format credential file at the location given.
        # As the current folder can vary in a shell or during script execution it is advised that you use specify a fully qualified path instead of a relative path.
        [Parameter(Position = 2, ValueFromPipelineByPropertyName)]
        [string] $ProfileLocation,

        ###

        # Used with SAML-based authentication when ProfileName references a SAML role profile. Contains the network credentials to be supplied during authentication with the configured identity provider's endpoint. This parameter is not required if the user's default network identity can or should be used during authentication.
        [Parameter(ValueFromPipelineByPropertyName)]
        [PSCredential] $NetworkCredential
    )

    process
    {
        [Hashtable] $get = @{}

        if ($null -ne $ProfileLocation)
        {
            $get.ProfileLocation = $ProfileLocation
        }

        if (!($credential = Get-AWSCredential -ProfileName:$ProfileName @get))
        {
            Write-Error -Category ObjectNotFound "The profile '${ProfileName}' was not found."
            return
        }

        # Set the credentials.
        [Hashtable] $set = @{}
        if ($null -ne $NetworkCredential) { $set.NetworkCredential = $NetworkCredential }

        # The only way to force them outside the scope seems to be to scope it to Global, mainly because AWS didn't bother allowing relative scoping.
        $credential | Set-AWSCredential -Scope Global @set

        # AWSCRAP: Credentials file is an .INI and *may* contain Region... but AWS's own tools don't read Region out.
        # So we have to.
        if (Get-Command 'Get-IniContent' -ErrorAction Ignore)
        {
            if (!$ProfileLocation)
            {
                # We need the default path.  Naturally, they don't return that in the default call either.
                # We can either make ANOTHER call to Get-AWSCredential to get the config info (without region...) or assume default.
                # Assuming default.
                $ProfileLocation = "~/.aws/credentials"
            }

            (Get-IniContent -FilePath $ProfileLocation).GetEnumerator() |
                Where-Object Name -ieq $ProfileName |
                Select-Object -First 1 -ExpandProperty Value |
                ForEach-Object {
                    Set-DefaultAWSRegion -Region $_.Region -Scope Global
                }
        }
        else
        {
            Write-Warning "PsIni not found.  Cannot load region from $($credential.ProfileLocation)"
        }


        # Now update environment
        $underlying = $credential.GetCredentials()
        if ($underlying)
        {
            # Found it!
            $Env:AWS_PROFILE = $ProfileName # $StoredAWSCredentials stringifies to profile name if set via profile, but it's probably not consistent.

            $Env:AWS_ACCESS_KEY_ID = $underlying.AccessKey
            $Env:AWS_SECRET_ACCESS_KEY = $underlying.SecretKey
            if ($underlying.UseToken)
            {
                $Env:AWS_SESSION_TOKEN = $underlying.Token
            }
            else
            {
                $Env:AWS_SESSION_TOKEN = ''
            }

            if ($StoredAWSRegion)
            {
                $Env:AWS_REGION = $StoredAWSRegion
            }
            elseif ($Env:AWS_DEFAULT_REGION)
            {
                $Env:AWS_REGION = $Env:AWS_DEFAULT_REGION
            }
        }
    }
}

<#
.SYNOPSIS
Stops the current in-memory AWS session.
#>
function Stop-AWSSession
{
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()

    # The only way to force them outside the scope seems to be to scope it to Global, mainly because AWS didn't bother allowing relative scoping.
    Clear-AWSCredential -Scope Global -ErrorAction Ignore
    Clear-DefaultAWSRegion -Scope Global -ErrorAction Ignore

    Clear-AWSEnvironment
}

#
# Tab Completion
#
if ($PSVersionTable.PSVersion.Major -ge 6)
{
    # Start-AWSSession: ProfileName
    Microsoft.PowerShell.Core\Register-ArgumentCompleter -CommandName 'Start-AWSSession' -ParameterName 'ProfileName' -ScriptBlock {
        param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

        if ($VerbosePreference) { Write-Verbose "argcomplete $commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters" }

        Get-AWSCredential -ListProfileDetail | Select-Object -ExpandProperty ProfileName | Where-Object { $_.StartsWith($wordToComplete, [StringComparison]::OrdinalIgnoreCase) }
        @()
    }
}

