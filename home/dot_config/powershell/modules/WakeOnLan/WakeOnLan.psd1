#
# Module manifest for module 'WakeOnLan'
#
# Chris Warwick, @cjwarwickps
#

@{

    # Script module or binary module file associated with this manifest.
    RootModule = 'WakeOnLan'

    # Version number of this module.
    ModuleVersion = '1.0'

    # ID used to uniquely identify this module
    GUID = '432e3fbf-3251-4d07-8110-592e195a2ece'

    # Author of this module
    Author = 'Chris Warwick'

    # Company or vendor of this module
    CompanyName = 'Nuney.com'

    # Copyright statement for this module
    Copyright = '(c) 2015 Chris Warwick. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'Sends Wake-on-Lan Magic Packets to the specified Mac addresses'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '2.0'

    # Functions to export from this module
    FunctionsToExport = 'Invoke-WakeOnLan'

    # Cmdlets to export from this module
    CmdletsToExport = ''

    # Variables to export from this module
    VariablesToExport = ''

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData = @{

        PSData = @{

            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @(
               'WakeOnLan'
               'WOL'
               'ARP'
               'MAC'
               'RFC826'
               'MagicPacket'
            )

            # A URL to the license for this module.
            LicenseUri = 'https://github.com/ChrisWarwick/WakeOnLan/blob/master/LICENSE'

            # A URL to the main website for this project.
            ProjectUri = 'https://github.com/ChrisWarwick/WakeOnLan'

            # ReleaseNotes of this module
            ReleaseNotes = 'Refer to Readme.md'

        } # End of PSData hashtable

    } # End of PrivateData hashtable

}

