#!/usr/bin/env bash
#
# Install PowerShell on everything but Windows.
#
set -o nounset -o errexit -o errtrace

function test_command() {
    command -v "$@" >/dev/null 2>/dev/null
}

function error() {
    echo >&2 -e "\e[31m[ERROR] " "$@" "\e[0m"
}

function warn() {
    echo >&2 -e "\e[33m[ WARN] " "$@" "\e[0m"
}

#
# OS detection
#

function load_osbits() {

    # Many of these are taken from:
    # - https://unix.stackexchange.com/questions/12453/how-to-determine-linux-kernel-architecture
    # - https://linoxide.com/linux-command/linux-commands-os-version/

    # getconf LONG_BIT will return:
    #   - 64 if purely 64-bit
    #   - 32 if purely 32-bit -OR- 32 if a 64-bit kernel was installed on 32-bit after the fact.
    # There is also a WORD_BIT but it is more likely to return 32 than 64 -- which it does on Win10 WSLs as of 2018-07-23.
    if test_command getconf && [[ $(getconf LONG_BIT) -eq 64 ]] ; then
        echo 64
        return 0
    fi

    # try os_arch (passed-in argument)

    case "${1?No architecture specified}" in
        x86_64)
            echo 64
            ;;
        x86 | i[3456]86)
            echo 32
            ;;
        armv[89]* | armv[1-9][0-9]*)
            # ARM v8: 64-bit.  Assume future ARMs are 64-bit for now.
            echo 64;
            ;;
        armv[1-7]* | armel | armhf)
            # ARM v7 and earlier: 32-bit
            # armel: ARMv4, Raspberry Pi
            # armhf: ARMv7, Raspberry Pi
            echo 32
            ;;
        *)
            # no idea, guess 32-bit.
            warn "unknown architecture '${1}'; assuming 32-bit"
            echo 32
            ;;
    esac
}

function load_distribution_info() {
    # cdonnelly 2016-04-28: BASHCRAP: There are only two ways to declare global variables:
    #   - Use "declare -g" (4.2 and later)
    #   - Don't use declare OR local (all versions)
    # Since we still need 3.x support, we do not do declare here unless exports are unneeded.
    # This does have the downside of negating strong typing, though.
    #
    # @seealso http://stackoverflow.com/questions/15867866/bash-exporting-attributes

    local uname=$(command -v uname)
    if [ -z "${uname}" ] ; then
        uname=/bin/uname
    fi

    # Get version
    os_version=$(${uname} -r 2>/dev/null )
    os_versinfo=( ${os_version//[^0-9a-zA-Z_]/ } )
    os_version_majorminor="${os_versinfo[0]:-0}.${os_versinfo[1]:-0}"
    os_version_majorminorrev="${os_version_majorminor}.${os_versinfo[2]:-0}"
    export   os_version os_versinfo os_version_majorminor os_version_majorminorrev
    readonly os_version os_versinfo os_version_majorminor os_version_majorminorrev

    # Get architecture name.
    os_arch=$(${uname} -m 2>/dev/null)
    os_bits="$(load_osbits "${os_arch}")"
    export   os_arch os_bits
    readonly os_arch os_bits

    # OS distribution: empty by default.
    os_distribution_id=''
    os_distribution_version=''
    os_distribution_versinfo=()
    os_distribution_version_majorminor=''

    # Need to handle various flavors of linux
    if test_command lsb_release ; then
        # lsb_release: tells you distro/release
        # @see http://serverfault.com/a/89711/9591
        os_distribution_id="$(lsb_release --short --id)"
        os_distribution_version="$(lsb_release --short --release)"

        os_distribution_versinfo=( ${os_distribution_version//[^0-9a-zA-Z_]/ } )
        os_distribution_version_majorminor="${os_distribution_versinfo[0]:-0}.${os_distribution_versinfo[1]:-0}"

    elif [ -e /etc/synouser.conf ] ; then
        # Synology
        os_distribution_id=Synology
        # https://forum.synology.com/enu/viewtopic.php?t=88109
        if [ -e /etc/VERSION ] ; then
            source /etc/VERSION
            os_distribution_version="${majorversion}.${minorversion}-${buildnumber}-${smallfixnumber}"
            os_distribution_versinfo=(${majorversion} ${minorversion} ${buildnumber} ${smallfixnumber})
            os_distribution_version_majorminor="${majorversion}.${minorversion}"

            # clear out the VERSION ones
            # if this list changes, we'llneed to do it ~live~ dynamically
            unset majorversion minorversion productversion buildphase buildnumber smallfixnumber packing_id packing builddate buildtime
        fi

    elif [ -e /etc/redhat-release -o -e /etc/centos-release ] ; then
        # RedHat Enterprise (older)
        os_distribution_id=RedHatEnterpriseServer
    else
        warn "Cannot resolve distribution ID"
    fi

    export   os_distribution_id os_distribution_version os_distribution_versinfo os_distribution_version_majorminor
    readonly os_distribution_id os_distribution_version os_distribution_versinfo os_distribution_version_majorminor

    # cdonnelly 2018-07-23: see if we are in Windows Subsystem for Linux
    # @see https://github.com/Microsoft/WSL/issues/423#issuecomment-221627364
    # BASHCRAP: 4.1 doesn't support -1 == N-1 indexing
    local last="${os_versinfo[${#os_versinfo[@]}-1]}"
    case "${last}" in
        WSL)
            os_virtualization='WSL'
            os_virtualization_version='1'
            ;;
        WSL?*)
            os_virtualization='WSL'
            os_virtualization_version="${last:3}"
            ;;
        *)
            # Virtualization: empty by default.
            os_virtualization=''
            os_virtualization_version=''
            ;;
    esac

    export   os_virtualization os_virtualization_version
    readonly os_virtualization os_virtualization_version
}

#
# Distro-specific installs
#
install_on_ubuntu() {
    # Ugh.  The setup for the apt package source is kind of a pain.
    if ! apt show powershell >/dev/null ; then
        # Requires microsoft source to have been run
        if ! apt show packages-microsoft-prod >/dev/null 2>/dev/null ; then
            error "Cannot install powershell: packages-microsoft-prod has not been installed yet."
        fi

        # ??? unsure what is going on.
        error "Cannot install powershell: packages-microsoft-prod is installed, but the package is not found"
    fi
}

install_on_synology() {
    error "Not implemented on synology"
    return 1
}

#
# Main
#
function main() {
    if test_command pwsh ; then
        return 0
    fi

    # Ensure profile vars are set.
    [ -n "${os_distribution_id+x}" ] || load_distribution_info

    case "${os_distribution_id}" in
        "Ubuntu")
            install_on_ubuntu
            ;;
        "Synology")
            install_on_synology
            ;;
        *)
            warn "Not yet implemented: distribution='${os_distribution_id}'"
            ;;
    esac
}

main