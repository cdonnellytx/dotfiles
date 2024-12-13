#!/usr/bin/env bash
#
# Function library
#

if declare -p __profile_functions >/dev/null 2>/dev/null; then
    __profile_warn "include.sh already included once"
    # RETURN, not EXIT, because tmux will exit on failure
    return 0
fi

export __profile_functions=1

####################################################################################################################################
# Debug/timing vars
####################################################################################################################################

# PROFILE_D_OUTPUT - where to output (default is stderr)
if [ -z "${PROFILE_D_OUTPUT+x}" ]; then
    declare PROFILE_D_OUTPUT=''
fi

# PROFILE_D_VERBOSE - write verbose messages about profile
if [ -z "${PROFILE_D_VERBOSE+x}" ] ; then
    declare -i PROFILE_D_VERBOSE=0
else
    # Ensure 0/1
    case "${PROFILE_D_VERBOSE}" in
        0 | 1) ;;
        '') PROFILE_D_VERBOSE=0 ;;
        *)  PROFILE_D_VERBOSE=1 ;;
    esac
fi

if [ -z "${PROFILE_D_TIMING+x}" ] ; then
    declare -i PROFILE_D_TIMING=0
else
    # Ensure 0/1/empty
    case "${PROFILE_D_TIMING}" in
        0 | 1) ;;
        '') PROFILE_D_TIMING=0 ;;
        *)  PROFILE_D_TIMING=1 ;;
    esac
fi

if [ -z "${PROFILE_D_CACHE+x}" ] ; then
    # cache by default
    declare -i PROFILE_D_CACHE=1
else
    # Ensure 0/1/empty
    case "${PROFILE_D_CACHE}" in
        0 | 1) ;;
        '') PROFILE_D_CACHE=1 ;;
        *)  PROFILE_D_CACHE=1 ;;
    esac
fi

####################################################################################################################################
# Cleanup
####################################################################################################################################

# @transient
# NOTE: Bash lets you iterate variable names starting with a prefix (${!PREFIX@} => all variables and functions starting with 'PREFIX').

# @transient
function __profile_cleanup() {
    # Unset any function names starting with `__profile_`
    # BASHCRAP: there is no good way to enumerate this without binary commands.
    unset $(declare -F | cut -d ' ' -f 3 | grep '^__profile_')

    # Unset any variable names starting with `__profile_`
    unset "${!__profile_@}"
}

####################################################################################################################################
# Interactive
####################################################################################################################################

# @persistent os_interactive: int

# is this shell interactive?
function __profile_is_os_interactive() {
    [[ ${os_interactive:-0} -gt 0 ]]
}

####################################################################################################################################
# Utils
####################################################################################################################################

declare -i __profile_mkdirif_supports_mode=1

function __profile_mkdirif() {
    [ -d "$1" ] && return 0
    if [ ${__profile_mkdirif_supports_mode} -ne 0 ] ; then
        mkdir -m 0700 -p "$1" && return 0
    else
        mkdir -p "$1" && return 0
    fi

    ret=$?
    __profile_error "Cannot mkdir '$1'"
    return $?
}

####################################################################################################################################
# Stack trace
####################################################################################################################################

function __profile_stacktrace() {
    local -i frame=${1:-0}
    local line
    echo "Stack trace:"
    while true; do
        line=$(caller ${frame})
        [ -z "${line}" ] && break
        echo "    ${line}"
        ((frame++))
    done
}

####################################################################################################################################
# Logging
####################################################################################################################################

function __profile_fail() {
    if [ $# -eq 0 ] ; then
        echo >&2 "Died"
    else
        echo >&2 "$@"
    fi

    # cdonnelly 2017-04-29: 'exit' in a profile will exit the shell completely.  Don't exit, just return
    return 255
}

# Cats output to where PROFILE_D_OUTPUT says to.
function __profile_cat_log() {
    if [ -z "${PROFILE_D_OUTPUT}" ] ; then
        /bin/cat >&2
    else
        /bin/cat >> "${PROFILE_D_OUTPUT}"
    fi
}

function __profile_log_enabled() {
    case "${1^^}" in
        FATAL) return 0 ;;
        ERROR) return 0 ;;
        WARN) return 0 ;;
        INFO) return 0 ;;
        DEBUG) [[ ${PROFILE_D_VERBOSE} -gt 0 ]] ;;
        TRACE) [[ ${PROFILE_D_VERBOSE} -gt 1 ]] ;;
        *) return 2;;
    esac
}

declare __profile_log_indent=''

function __profile_increase_indent() {
    __profile_log_indent+='  '
}

function __profile_decrease_indent() {
    [ -n "${__profile_log_indent+x}" ] && __profile_log_indent="${__profile_log_indent:0:-2}"
}

function __profile_format_log_header() {
    local level="${1}"
    printf '%s[%-6s] ' "${__profile_log_indent}" "${level^^}"
}

function __profile_log() {
    __profile_is_os_interactive || return 0
    local level="$1"; shift
    __profile_log_enabled "${level}" || return

    (
        __profile_format_log_header "${level}"
        echo $@
    ) | __profile_cat_log
}

function __profile_log_vars() {
    __profile_is_os_interactive || return 0
    local level="$1"; shift
    __profile_log_enabled "${level}" || return

    if [ ${BASH_VERSINFO[0]} -ge 4 ] ; then
        # Bash 4.x
        # cdonnelly 2019-10-01: It is possible for the next like to report "/dev/fd/62: no such file or directory"
        # If that happens it means /dev is either not installed correctly or otherwise hosed.
        # @see https://github.com/git-for-windows/git/issues/2291 for an example...
        local format=$(__profile_format_log_header "${level}")
        local -a __lines

        mapfile -t __lines < <(declare -p "$@")
        printf "${format}%s \n" "${__lines[@]}" | __profile_cat_log
    else
        # Bash 3.x and earlier
        declare -p "$@" | __profile_cat_log
    fi
}

function __profile_error() {
    __profile_log ERROR $@
}

function __profile_warn() {
    __profile_log WARN $@
}

function __profile_info() {
    __profile_log INFO $@
}

function __profile_debug() {
    __profile_log DEBUG "$@"
}

function __profile_debug_vars() {
    __profile_log_vars DEBUG "$@"
}

function __profile_trace() {
    __profile_log TRACE "$@"
}

function __profile_trace_vars() {
    __profile_log_vars TRACE "$@"
}

####################################################################################################################################
# Cache
####################################################################################################################################

declare __profile_cache_token=-buildcache
declare -i __profile_cache_needed=66

function __profile_cache_ok() {
    [ "$1" == "${__profile_cache_token}" ]
}

function __profile_cache_escape_output() {
    # @see http://stackoverflow.com/questions/1251999/how-can-i-replace-a-newline-n-using-sed
    if [ $# -eq 0 ] ; then
        sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/\n#\t/g'
    else
        echo "$@" | sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/\n#\t/g'
    fi
}

####################################################################################################################################
# Profile
####################################################################################################################################

function __profile_source() {
    local config_script="${1?Value cannot be null or empty.}"
    local cache_script="${2?Value cannot be null or empty.}"

    # If caching, and a cache file exists, use it.
    if [[ ${PROFILE_D_CACHE} -ne 0 && -e "${cache_script}" ]] ; then
        __profile_debug "SRC ${cache_script}"
        source "${cache_script}"
        return $?
    fi

    __profile_debug "SRC ${config_script}"
    if source "${config_script}" ; then
        return 0
    elif [ $? -eq ${__profile_cache_needed} ] ; then
        # Generate the cache script source.
        # HACK: Because mapfile or the array invocation swallows the exit code from `source`,
        # we have to handle errors in the mapfile array command.
        local -a src
        local marker="__profile_warn \"Cache script for '${config_script}' was not generated correctly\""
        mapfile -t src < <(
            if ! source "${config_script}" -buildcache ; then
                echo "${marker}"
                return 1
            fi
        )
        __profile_debug_vars src

        if [ ${PROFILE_D_CACHE} -eq 0 ] ; then
            # Eval the "cache" script; do not actually cache it.
            __profile_debug "EVAL ${config_script}"
            if [ ${#src[@]} -gt 0 ] ; then
                eval "${src[@]}"
            fi
        else
            # Cache.
            __profile_debug "CACHE ${config_script} in '${cache_script}'" 
            __profile_mkdirif "$(dirname "${cache_script}")"

            # config_script is meant to be cached
            __profile_trace "WRITE ${cache_script}"
            echo "#!/usr/bin/env bash" > "${cache_script}"
            printf '%s\n' "${src[@]}" >> "${cache_script}"

            __profile_trace "SRC ${cache_script}"
            source "${cache_script}" >/dev/null
        fi
    else
        # Other error code
        return $?
    fi
}

function __profile_exec_with_timing() {
    local TIMEFORMAT

    case $# in
        1) echo -n >&2 "${__profile_log_indent}${1}" ;;
        2) echo -n >&2 "${__profile_log_indent}${1} ${2}" ;;
        *)
            case "$1" in
                # conditional brace: print the whole thing.
                '[' | '[[') echo -n >&2 "${__profile_log_indent}$@" ;;
                *) echo -n >&2 "${__profile_log_indent}${1} ${2} ..." ;;
            esac
            ;;
    esac

    # Capture current indent before executing anything.
    local indent="${__profile_log_indent}"

    __profile_increase_indent
    # newline + braces for nested items
    echo >&2 " {"
    TIMEFORMAT="${indent}} => %3R"
    time "$@"
    __profile_decrease_indent 2>/dev/null # to avoid issues at cleanup, ignore if this function fails.
}

# @private @transient
# Loads an individual .conf file or directory.
# @param string config_dir  The directory of config files to source recursively.
# @param string cache_dir   The directory for cache files.
function __profile_source_d() {
    local config_dir="${1?Value cannot be null or empty.}"
    local cache_dir="${2?Value cannot be null or empty.}"

    __profile_log_enabled DEBUG && __profile_debug "SRCD ${config_dir%/}/"

    [ -d "${config_dir}" ] || return 2

    __profile_increase_indent
    local config_script cache_script
    for config_script in "${config_dir}"/*.conf; do
        cache_script="${cache_dir}/${config_script##*/}" # basename, but performant.

        if [ -d "${config_script}" ] ; then
            ${PROFILE_D_WRAPPER} __profile_source_d "${config_script}" "${cache_script}" || __profile_trace "'${config_script}' exited with code $?"
        elif [ -f "${config_script}" ] ; then
            ${PROFILE_D_WRAPPER} __profile_source "${config_script}" "${cache_script}" || __profile_trace "'${config_script}' exited with code $?"
        # else: glob didn't expand.  Don't warn if it's missing.
        fi
    done

    __profile_decrease_indent

    return 0
}

function __profile_load_osbits() {

    # Many of these are taken from:
    # - https://unix.stackexchange.com/questions/12453/how-to-determine-linux-kernel-architecture
    # - https://linoxide.com/linux-command/linux-commands-os-version/

    # getconf LONG_BIT will return:
    #   - 64 if purely 64-bit
    #   - 32 if purely 32-bit -OR- 32 if a 64-bit kernel was installed on 32-bit after the fact.
    # There is also a WORD_BIT but it is more likely to return 32 than 64 -- which it does on Win10 WSLs as of 2018-07-23.
    if command -v >/dev/null 2>/dev/null getconf && [[ $(getconf LONG_BIT) -eq 64 ]] ; then
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
            __profile_warn "unknown architecture '${1}'; assuming 32-bit"
            echo 32
            ;;
    esac
}

function __profile_load_osinfo() {
    # cdonnelly 2016-04-28: BASHCRAP: There are only two ways to declare global variables:
    #   - Use "declare -g" (4.2 and later)
    #   - Don't use declare OR local (all versions)
    # Since we still need 3.x support, we do not do declare here unless exports are unneeded.
    # This does have the downside of negating strong typing, though.
    #
    # @seealso http://stackoverflow.com/questions/15867866/bash-exporting-attributes
    case $- in
        *i*)
            os_interactive=1
            ;;
        *)
            os_interactive=0
            ;;
    esac
    export               os_interactive
    readonly             os_interactive
    __profile_debug_vars os_interactive


    local uname=$(command -v 2>/dev/null uname)
    if [ -z "${uname}" ] ; then
        uname=/bin/uname
    fi

    # Get version
    os_version=$(${uname} -r 2>/dev/null )
    os_versinfo=( ${os_version//[^0-9a-zA-Z_]/ } )
    os_version_majorminor="${os_versinfo[0]:-0}.${os_versinfo[1]:-0}"
    os_version_majorminorrev="${os_version_majorminor}.${os_versinfo[2]:-0}"
    export               os_version os_versinfo os_version_majorminor os_version_majorminorrev
    readonly             os_version os_versinfo os_version_majorminor os_version_majorminorrev
    __profile_debug_vars os_version os_versinfo os_version_majorminor os_version_majorminorrev

    # Get architecture name.
    os_arch=$(${uname} -m 2>/dev/null)

    # Note both Cygwin and MinGW/MSYS both require special handling to strip the Windows version.
    os_type=$(${uname} -s 2>/dev/null)

    # empty cachekey by default, since only Windows has multiple envs
    os_cachekey=''

    os_bits="$(__profile_load_osbits "${os_arch}")"

    # OS distribution: empty by default.
    os_distribution_id=''
    os_distribution_version=''
    os_distribution_versinfo=()
    os_distribution_version_majorminor=''

    os_flags=()

    os_has_flag() {
        local flag="${1?Flag cannot be null or empty}"
        declare f
        for f in "${os_flags[@]}"; do
            [ "${f}" == "${flag}" ] && return 0
        done

        return 1
    }

    # Virtualization: empty by default.
    os_virtualization=''
    os_virtualization_version=''

    case "${os_type}" in
        # MSYS2 vs MSYS vs MSYSGIT vs Cygwin:
        # https://gist.github.com/ReneNyffenegger/a8e9aa59166760c5550f993857ee437d
        # Because multiple environments (and multiple installs of each!) can exist on the same Windows machine,
        # we use additional cachekey bits.
        CYGWIN* | MSYS* | MINGW*)
            # Fortunately they all have similar `uname -s` as of 2022-01-18.
            # MINGW does 32/64 bits, none of the others do.
            # MSYS2 just says MSYS in the uname.
            local -r re_os_details='^(CYGWIN|MSYS|MINGW)(32|64)?_NT-([0-9]+([.-][0-9]+)*)(-WOW64)?'
            if [[ "${os_type}" =~ $re_os_details ]] ; then
                os_subtype="${BASH_REMATCH[1],,}"

                case "${BASH_REMATCH[5]}" in
                    # 32-bit mode on a 64-bit OS; override os_bits
                    '-WOW64')
                        os_bits=32
                        os_flags+=('WOW64')
                        ;;
                    *)
                        # Look for explicit
                        if [ -n "${BASH_REMATCH[2]}" ] ; then
                            os_bits="${BASH_REMATCH[2]}"
                        fi
                        ;;
                esac

                os_windows_version="${BASH_REMATCH[3]}"
                os_windows_versinfo=( ${os_windows_version//[^0-9a-zA-Z_]/ } )
                os_windows_version_majorminor="${os_windows_versinfo[0]:-0}.${os_windows_versinfo[1]:-0}"
            else
                # Some change to the variant
                __profile_warn "Cannot parse Cygwin/MinGW/MSYS OS string: '${os_type}'"
                os_subtype="${os_type}"
            fi

            os_type="Windows"

            os_distribution_id="${os_subtype}"
            os_distribution_version="${os_version}"

            os_cachekey="${os_subtype}${os_bits}"

            # Subtypes require logical handling.
            case "${os_subtype}" in
                msys)
                    # MSYS, MINGW cannot set permissions properly in $USERPROFILE
                    __profile_mkdirif_supports_mode=0
                    ;;

                mingw)
                    # MSYS, MINGW cannot set permissions properly in $USERPROFILE
                    __profile_mkdirif_supports_mode=0
                    ;;

                cygwin)
                    ;;
            esac

            export               os_windows_version os_windows_versinfo os_windows_version_majorminor
            readonly             os_windows_version os_windows_versinfo os_windows_version_majorminor
            __profile_debug_vars os_windows_version os_windows_versinfo os_windows_version_majorminor

            # Cygwin has "cygpath" to translate paths.
            # MSYS/MSYS2/MinGW have this as well, although they also attempt to translate the paths on their own when invoking commands.
            os_get_native_fullpath() {
                cygpath -aw "$@"
            }
            os_get_safe_fullpath() {
                cygpath -am "$@"
            }
            os_get_unix_fullpath() {
                cygpath -au "$@"
            }

            # MSYS/MSYS2/MinGW anti-mangle command invoker
            os_invoke_with_paths() {
                MSYS2_ARG_CONV_EXCL="*" MSYS_NO_PATHCONV=1 "$@"
            }

            ;;
        Linux)
            # Need to handle various flavors of linux
            if command -v >/dev/null 2>/dev/null lsb_release ; then
                # lsb_release: tells you distro/release
                # @see http://serverfault.com/a/89711/9591
                os_distribution_id="$(lsb_release --short --id)"
                os_distribution_version="$(lsb_release --short --release)"

                os_distribution_versinfo=( ${os_distribution_version//[^0-9a-zA-Z_]/ } )
                os_distribution_version_majorminor="${os_distribution_versinfo[0]:-0}.${os_distribution_versinfo[1]:-0}"

                case "${os_distribution_id}" in
                    RedHatEnterpriseServer|CentOS)
                        os_subtype=RedHat
                        ;;
                    *)
                        os_subtype="${os_distribution_id}"
                        ;;
                esac

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
                        ;;
                esac

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

                os_subtype=Synology
            elif [ -e /etc/redhat-release -o -e /etc/centos-release ] ; then
                # RedHat Enterprise (older)
                os_subtype=RedHat
            else
                os_subtype=unknown
            fi

            ;;
        Darwin)
            # ASSUMPTION: It's macOS.
            # NOTE: macOS readlink is BSD and doesn't support -f, so we have to implement it differently
            os_subtype=macOS
            os_get_unix_fullpath()
            {
                __profile_debug "dirname 1='${1}'" 
                cd `dirname $1`;
                __filename=`basename $1`;
                if [ -h "$__filename" ]; then
                    os_get_unix_fullpath `readlink $__filename`;
                else
                    echo "`pwd -P`";
                fi
            }
            ;;
        *)
            # Unknown. No OS-level cachekey.
            os_subtype=Unknown
            ;;
    esac

    if [ -n "${os_subtype}" ] ; then
        os_archtoken="${os_type}-${os_subtype}-${os_arch}"
    else
        os_archtoken="${os_type}-${os_arch}"
    fi

    os_archpath="${os_archtoken//-//}"

    export               os_type os_subtype os_arch os_archpath os_archtoken os_bits os_cachekey os_flags
    readonly             os_type os_subtype os_arch os_archpath os_archtoken os_bits os_cachekey os_flags
    __profile_debug_vars os_type os_subtype os_arch os_archpath os_archtoken os_bits os_cachekey os_flags

    export -f os_get_safe_fullpath os_get_native_fullpath os_get_unix_fullpath

    export               os_interactive os_version os_versinfo os_version_majorminor os_version_majorminorrev
    readonly             os_interactive os_version os_versinfo os_version_majorminor os_version_majorminorrev
    __profile_debug_vars os_interactive os_version os_versinfo os_version_majorminor os_version_majorminorrev

    export               os_distribution_id os_distribution_version os_distribution_versinfo os_distribution_version_majorminor
    readonly             os_distribution_id os_distribution_version os_distribution_versinfo os_distribution_version_majorminor
    __profile_debug_vars os_distribution_id os_distribution_version os_distribution_versinfo os_distribution_version_majorminor

    export               os_virtualization os_virtualization_version
    readonly             os_virtualization os_virtualization_version
    __profile_debug_vars os_virtualization os_virtualization_version
}

# Loads the profile.
# @param {string[]} profile_path   The paths to execute as part of the profile.
function __profile_load() {
    if [ $# -eq 0 ] ; then
        __profile_fail "Must specify one or more profile paths"
    fi

    local TIMEFORMAT=' => %3R'

    # Resolve the HOME cache equivalent.
    # Cache by:
    #   - hostname (for multi-machine environments sharing a home directory)
    #   - os_cachekey (for cases when multiple envs exist, like Cygwin/MSYS)
    local cache_home="${XDG_CACHE_ROOT:-${HOME}/.cache}/dotfiles-profile/${HOSTNAME}"
    if [ -n "${os_cachekey+${os_cachekey}}" ] ; then
        cache_home+="/${os_cachekey}"
    fi
    readonly cache_home

    __profile_mkdirif "${cache_home}" || return 2

    local profile_path
    for profile_path; do
        local cache_dir="${profile_path/${HOME}/${cache_home}}"

        ${PROFILE_D_WRAPPER} __profile_source_d "${profile_path}" "${cache_dir}" || continue
        if [ -n "${os_type}" ] ; then
            ${PROFILE_D_WRAPPER} __profile_source_d "${profile_path}/${os_type}" "${cache_dir}/${os_type}" || continue
            [ -z "${os_subtype}" ] || ${PROFILE_D_WRAPPER} __profile_source_d "${profile_path}/${os_type}/${os_subtype}" "${cache_dir}/${os_type}/${os_subtype}"
            [ -z "${os_virtualization}" ] || ${PROFILE_D_WRAPPER} __profile_source_d "${profile_path}/${os_type}/${os_virtualization}" "${cache_dir}/${os_type}/${os_virtualization}"
        fi
    done

    __profile_cleanup
}

####################################################################################################################################
# Version functions
####################################################################################################################################

function __profile_version_is() {
    local l_version op r_version
    case $# in
        0 | 1)
            __profile_warn "__profile_version_is: Not enough arguments"
            return 255
            ;;
        2)
            # assumes equality
            l_version="${1}"
            op='-eq'
            r_version="${2}"
            ;;
        *)
            l_version="${1}"
            op="${2}"
            r_version="${3}"
            ;;
    esac

    __profile_trace "'${l_version}' ${op} '${r_version}'"

    # we also need string ops
    local -a string_ops
    case "${op}" in
        '-eq') string_ops=('==') ;;
        '-ne') string_ops=('!=') ;;
        '-lt') string_ops=('<') ;;
        '-le') string_ops=('<' '==') ;; # BASHCRAP: there is no >= operator, there is > and there is =
        '-gt') string_ops=('>') ;;
        '-ge') string_ops=('>' '==') ;;
        *)
            __profile_warn "unknown/unsupported operator ${op}.  Continuing though we may have problems"
            ;;
    esac

    local -a l_versinfo=( ${l_version//[^0-9a-zA-Z_]/ } ) # split on all possible delimiters
    local -a r_versinfo=( ${r_version//[^0-9a-zA-Z_]/ } ) # split on all possible delimiters
    local -i i
    local -i last_was_eq=0
    for i in "${!r_versinfo[@]}"; do
        last_was_eq=0
        __profile_trace "cmp: $i: ${l_versinfo[i]} ${op} ${r_versinfo[i]}"

        # Have to compare and check $? this way, doing an if statement doesn't preserve value of $?
        [ ${l_versinfo[i]} ${op} ${r_versinfo[i]} ] 2>/dev/null
        case $? in
            0)
                # The op worked (answer: true)
                # If we were using an inequality (-ne/-lt/-gt and conditionally -le/-ge), we can exit early.
                # Otherwise, we have to keep comparing digits.
                case "${op}" in
                    '-eq')
                        # keep checking
                        ;;
                    '-ne' | '-lt' | '-gt')
                        # we succeeded outright
                        __profile_trace "        => true (ne)"
                        return 0
                        ;;
                    '-le' | '-ge')
                        if [[ ${l_versinfo[i]} -ne ${r_versinfo[i]} ]] ; then
                            __profile_trace "        => true (ne)"
                            return 0
                        fi
                        ;;
                esac

                # Keep checking
                __profile_trace "        => true (eq)"
                continue
                ;;

            1)
                # The op worked (answer: false)
                # fall through
                ;;
            2)
                # numeric op failed.  Try string ops
                if [[ ${#string_ops[@]} -eq 0 ]] ; then
                    __profile_warn "Numeric comparison failed and no string operations exist for operator ${op}"
                    return 2
                fi

                local sop
                local -i found=0
                for sop in "${string_ops[@]}" ; do
                    if [ "${l_versinfo[i]}" ${sop} "${r_versinfo[i]}" ] ; then
                        found=1
                        break
                    fi
                done

                if [ ${found} -eq 0 ] ; then
                    __profile_trace "        => false (string)"
                    return 1
                fi

                case "${op}" in
                    '-eq')
                        # keep checking
                        ;;
                    '-ne' | '-lt' | '-gt')
                        # we succeeded outright
                        __profile_trace "        => true (string-ne)"
                        return 0
                        ;;
                    '-le' | '-ge')
                        if [[ ${l_versinfo[i]} -ne ${r_versinfo[i]} ]] ; then
                            __profile_trace "        => true (string-ne)"
                            return 0
                        fi
                        ;;
                esac

                __profile_trace "        => true (string-eq)"
                continue
                ;;
            *)
                __profile_warn "Unexpected: comparison result was $?"
                return 2
                ;;
        esac


        if [[ "${op}" != '-ne' && ${l_versinfo[i]} -eq ${r_versinfo[i]} ]] ; then
            # our op is not -eq or -ne, and failed, but the values are equal.  keep checking
            __profile_trace "        => false, but equal and ${op} != -ne"
            last_was_eq=1
            continue
        fi

        if __profile_log_enabled TRACE ; then
            __profile_trace "        => false"
            __profile_trace "fail"
            __profile_trace_vars i l_versinfo op r_versinfo last_was_eq
        fi
        return 1
    done

    # return TRUE (0) if last was a real compare, not an "equality and keep going" compare
    if __profile_log_enabled TRACE ; then
        __profile_trace "maybe success (${last_was_eq})"
        __profile_trace_vars i l_versinfo op r_versinfo last_was_eq
    fi
    return ${last_was_eq}
}

####################################################################################################################################
# Bash version functions
####################################################################################################################################

function __profile_bash_version_is() {
    local op r_version
    case $# in
        0)
            __profile_warn "__profile_bash_version_is: Not enough arguments"
            return 255
            ;;
        1)
            # assumes equality
            op='-eq'
            r_version="$1"
            ;;
        *)
            op="$1"
            r_version="$2"
            ;;
    esac

    __profile_trace "'${BASH_VERSION}' ${op} '${r_version}'"

    # we also need string ops
    local -a string_ops
    case "${op}" in
        '-eq') string_ops=('==') ;;
        '-ne') string_ops=('!=') ;;
        '-lt') string_ops=('<') ;;
        '-le') string_ops=('<' '==') ;; # BASHCRAP: there is no >= operator, there is > and there is =
        '-gt') string_ops=('>') ;;
        '-ge') string_ops=('>' '==') ;;
        *)
            __profile_warn "unknown/unsupported operator ${op}.  Continuing though we may have problems"
            ;;
    esac

    local -a r_versinfo=( ${r_version//[^0-9a-zA-Z_]/ } ) # split on all possible delimiters
    local -i i
    local -i last_was_eq=0
    for i in "${!r_versinfo[@]}"; do
        last_was_eq=0
        __profile_trace "cmp: $i: ${BASH_VERSINFO[i]} ${op} ${r_versinfo[i]}"

        # BASHCRAP: have to compare and check $? this way, doing an if statement doesn't preserve value of $?
        [ ${BASH_VERSINFO[i]} ${op} ${r_versinfo[i]} ] 2>/dev/null
        case $? in
            0)
                # our op worked.
                # If we were using an inequality (-ne/-lt/-gt and conditionally -le/-ge), we can exit early.
                # Otherwise, we have to keep comparing digits.
                case "${op}" in
                    '-eq')
                        # keep checking
                        ;;
                    '-ne' | '-lt' | '-gt')
                        # we succeeded outright
                        __profile_trace "        => true (ne)"
                        return 0
                        ;;
                    '-le' | '-ge')
                        if [[ ${BASH_VERSINFO[i]} -ne ${r_versinfo[i]} ]] ; then
                            __profile_trace "        => true (ne)"
                            return 0
                        fi
                        ;;
                esac

                # Keep checking
                __profile_trace "        => true (eq)"
                continue
                ;;

            1)
                # fall through
                ;;
            2)
                # numeric op failed.  Try string ops
                if [[ ${#string_ops[@]} -eq 0 ]] ; then
                    __profile_warn "Numeric comparison failed and no string operations exist for operator ${op}"
                    return 2
                fi

                #__profile_trace "        => as string: ${BASH_VERSINFO[i]} ${string_ops[*]} ${r_versinfo[i]}"

                local sop
                local -i found=0
                for sop in "${string_ops[@]}" ; do
                    if [ "${BASH_VERSINFO[i]}" ${sop} "${r_versinfo[i]}" ] ; then
                        found=1
                        break
                    fi
                done

                if [ ${found} -eq 0 ] ; then
                    __profile_trace "        => false (string)"
                    return 1
                fi

                case "${op}" in
                    '-eq')
                        # keep checking
                        ;;
                    '-ne' | '-lt' | '-gt')
                        # we succeeded outright
                        __profile_trace "        => true (string-ne)"
                        return 0
                        ;;
                    '-le' | '-ge')
                        if [[ ${BASH_VERSINFO[i]} -ne ${r_versinfo[i]} ]] ; then
                            __profile_trace "        => true (string-ne)"
                            return 0
                        fi
                        ;;
                esac

                __profile_trace "        => true (string-eq)"
                continue
                ;;
            *)
                __profile_warn "Unexpected: comparison result was $?"
                return 2
                ;;
        esac


        if [[ "${op}" != '-ne' && ${BASH_VERSINFO[i]} -eq ${r_versinfo[i]} ]] ; then
            # our op is not -eq or -ne, and failed, but the values are equal.  keep checking
            __profile_trace "        => false, but equal and ${op} != -ne"
            last_was_eq=1
            continue
        fi

        if __profile_log_enabled TRACE ; then
            __profile_trace "        => false"
            __profile_trace "fail"
            __profile_trace_vars i BASH_VERSINFO op r_versinfo last_was_eq
        fi
        return 1
    done

    # return TRUE (0) if last was a real compare, not an "equality and keep going" compare
    if __profile_log_enabled TRACE ; then
        __profile_trace "maybe success (${last_was_eq})"
        __profile_trace_vars i BASH_VERSINFO op r_versinfo last_was_eq
    fi
    return ${last_was_eq}
}

function __profile_bash_require() {
    if ! __profile_bash_version_is -ge "$1" ; then
        __profile_debug "bash ${1} or higher required."
        return 1
    fi

    return 0
}

####################################################################################################################################
# PATH variable management
####################################################################################################################################

function __profile_insert_into_path_before() {
    local usage='Usage: __profile_insert_into_path_before NAME INSERT_BEFORE VALUE...'
    local name="${1?${usage}}" ; shift
    local insert_before="${1?${usage}}" ; shift

    if [ $# -eq 0 ] ; then
        __profile_error "${usage}"
        return 1
    fi

    local -i changed=0

    local mode=''
    __profile_trace "__profile_insert_into_path_before: assigning pname=${name}"
    if __profile_bash_version_is -ge 4.3 ; then
        # cdonnelly 2018-03-08: "-n" exists in bash 4.3 and later. (Definitely not 4.2)
        local -n pname="${name}"
    else
        # bash 4.2 and earlier: do eval to read, then to write at end.
        # the rest of the functionality should be the same.
        local pname=$(eval "if [ -n \"\${${name}+x}\" ] ; then echo \${${name}} ; fi")
        mode='legacy'
    fi

    local value
    for value in "$@"; do
        if [ "${value}" == "${insert_before}" ] ; then
            __profile_warn "__profile_insert_into_path_before: value and insert_before cannot be same value"
            continue
        fi

        case "${pname}" in
            "")
                # trivial case
                __profile_debug "__profile_insert_into_path_before: '${name}' is empty.  ACTION: set to '${value}'."
                pname="${value}"
                changed=1
                ;;

            "${value}:"*)
                # starts with $value.  Do nothing.
                __profile_debug "__profile_insert_into_path_before: '${name}' starts with value='${value}'.  ACTION: do nothing"
                ;;

            "${insert_before}" | "${insert_before}:"*)
                # starts with $insert_before.  Add $value.
                __profile_debug "__profile_insert_into_path_before: '${name}' starts with insert_before='${insert_before}'.  ACTION: prepend '${value}'."
                pname="${value}:${pname}"
                changed=1
                ;;

            *":${insert_before}:"* | *":${insert_before}")
                # $insert_before is in the middle or end of $name.
                # Is $value already ahead of it?
                case "${pname}" in
                    *":${value}:${insert_before}:"*   | *":${value}:${insert_before}")
                        # already before: do nothing
                        __profile_debug "__profile_insert_into_path_before: '${name}' already has '${value}' right before '${insert_before}'.  ACTION: do nothing"
                        ;;
                    *":${value}:*:${insert_before}:"* | *":${value}:*:${insert_before}")
                        # already before: do nothing
                        __profile_debug "__profile_insert_into_path_before: '${name}' already has '${value}' some distance before '${insert_before}'.  ACTION: do nothing"
                        ;;
                    *)
                        # $value is not before $insert_before (or not in $name altogether)
                        __profile_debug "__profile_insert_into_path_before: '${name}' has '${insert_before}' before '${value}'; fixing.  ACTION: replace."
                        local old_str new_str
                        case "${pname}" in
                            *":${insert_before}:"*)
                                old_str=":${insert_before}:"
                                new_str=":${value}:${insert_before}:"
                                ;;
                            *":${insert_before}")
                                # cdonnelly 2016-05-23: Yes there's a possibility you have a case like ":${insert_before}/baz" in the $name before ":${insert_before}"
                                # and we inject "value" before the former, but this is acceptable for now.
                                old_str=":${insert_before}"
                                new_str=":${value}:${insert_before}"
                                ;;
                            *)
                                # should not happen
                                __profile_fail "how did we get here ${name}='${pname}'"
                                return 255
                                ;;
                        esac
                        pname="${pname/${old_str}/${new_str}}"
                        changed=1
                        ;;
                esac
                ;;

            *":${value}:"* | *":${value}")
                # $insert_before is not in $name, but $value is: do nothing
                __profile_debug "__profile_insert_into_path_before: '${name}' has value='${value}' but not insert_before='${insert_before}'.  ACTION: do nothing"
                ;;
            *)
                # Neither $value nor $insert_before is in $name.
                # Just append $value to $name.
                __profile_debug "__profile_insert_into_path_before: Neither value in '${name}'.  ACTION: append '${value}'"
                pname="${pname}:${value}"
                changed=1
                ;;
        esac
    done

    if [[ ${changed} -ne 0 && "${mode}" == 'legacy' ]] ; then
        eval "export ${name}='${pname}'"
    fi
}

function __profile_add_to_path_variable() {
    local usage='Usage: __profile_add_to_path_variable [-a|--append|-p|--prepend] NAME VALUE...'
    local -i prepend=0
    case "${1?${usage}}" in
        '-p' | '--prepend')
            prepend=1
            shift
            ;;
        '-a' | '--append')
            # default behavior
            shift
            ;;
    esac

    local name="${1?${usage}}"; shift
    if [ -z "${name}" ] ; then
        __profile_error "${usage}"
        return 1
    fi

    # any more args?
    if [ $# -eq 0 ] ; then
        __profile_error "${usage}"
        return 1
    fi

    local mode=''
    __profile_trace "__profile_add_to_path_variable: assigning pname=${name}"
    if __profile_bash_version_is -ge 4.3 ; then
        # cdonnelly 2018-03-08: "-n" exists in bash 4.3 and later. (Definitely not 4.2)
        local -n pname="${name}"
    else
        # bash 4.1 and earlier: do eval to read, then to write at end.
        # the rest of the functionality should be the same.
        local pname=$(eval "if [ -n \"\${${name}+x}\" ] ; then echo \${${name}} ; fi")
        mode='legacy'
    fi

    local value
    for value in "$@"; do
        if [[ -z "${pname+${name}}" ]] ; then
            __profile_debug "__profile_add_to_path_variable: '${name}' is null or empty.  ACTION: set to '${value}'."
            pname="${value}"
        elif [[ "${pname}" == "${value}" || "${pname}" == "${value}:"* ]] ; then
            # Already first path
            __profile_debug "__profile_add_to_path_variable: '${name}' is not empty, '${value}' first entry.   ACTION: nothing."
        elif [[ ${prepend} -ne 0 ]] ; then
            __profile_debug "__profile_add_to_path_variable: '${name}' is not empty, '${value}' not first entry.  ACTION: prepend."
            pname="${value}:${pname}"
        elif [[ "${pname}" == *":${value}:"* || "${pname}" == *":${value}" ]] ; then
            # Already in path (middle or end)
            __profile_debug "__profile_add_to_path_variable: '${name}' is not empty, '${value}' already present.   ACTION: nothing."
        else
            __profile_debug "__profile_add_to_path_variable: '${name}' is not empty, '${value}' not present.  ACTION: append."
            pname="${pname}:${value}"
        fi
    done

    if [ "${mode}" == 'legacy' ] ; then
        eval "export ${name}='${pname}'"
    fi
}


####################################################################################################################################
# Safe path manipulation
####################################################################################################################################

#
# @public @export
# Gets the true native-UNIX path.
#
function os_get_unix_fullpath() {
    readlink -f "$@"
}

#
# @public @export
# Gets the true native OS path.
# On all but Windows, this is equivalent to os_get_unix_fullpath.
# On Windows, this returns a standard Windows path.
#
function os_get_native_fullpath() {
    os_get_unix_fullpath "$@"
}

#
# @public @export
# Gets the true native OS path.
# On all but Windows, this is equivalent to os_get_unix_fullpath.
# On Windows, this returns a standard Windows path but with forward slashes (aka what Cygwin calls "mixed").
#
function os_get_safe_fullpath() {
    os_get_unix_fullpath "$@"
}

function __profile_create_os_safe_path_remapper() {
    local prog="$1"
    local progpath="${2:-${prog}}"

    eval "
function ${prog}() {
    local -a args
    while [[ \$# -gt 0 ]] ; do
        if [[ \$1 =~ ^/ ]] ; then
            args+=(\"\$(os_get_safe_fullpath \"\$1\")\")
        else
            args+=(\"\$1\")
        fi
        shift
    done

    command '${progpath}' \"\${args[@]}\"
}
"
    export -f "${prog}"
}

####################################################################################################################################

if [ ${PROFILE_D_TIMING} -ne 0 ] ; then
    export PROFILE_D_WRAPPER=__profile_exec_with_timing
else
    export PROFILE_D_WRAPPER=''
fi

####################################################################################################################################

__profile_debug "functions.sh loaded."
