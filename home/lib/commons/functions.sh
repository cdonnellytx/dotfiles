#!/usr/bin/env bash
#
# Shared functions
#

if declare -Ff __common_functions >/dev/null 2>/dev/null; then
    warn "functions.sh already included once"
    exit 0
fi

__common_functions() {
    # Bash abhors an empty function
    echo "Shared functions"
}

####################################################################################################################################
# Stack trace
####################################################################################################################################

_stacktrace() {
    local -i frame=${1:-0}
    local line
    echo "Stack trace:"
    while true; do
        line=$(caller ${frame})
        if [ -z "${line}" ] ; then
            break
        fi
        echo "    ${line}"
        ((frame++))
    done
}

####################################################################################################################################
# Logging
####################################################################################################################################

declare -i log_level=0

_log_print_level() {
    if [ -n "${level}" ] ; then
        printf '[%-6s] ' ${level}
    fi
}

_log_stacktrace() {
    if [ ${use_stacktrace} -ne 0 ] ; then
        # Exclude:
        #   1. _log_stacktrace
        #   2. caller of _log_stacktrace (a _logXXX function)
        #   3. caller of _logXXX
        _stacktrace 3
    fi
}

_log() {
    # Parse out log+echo options
    local -a echo_opts=()
    local -i use_stacktrace=0
    local level=''
    local default_message
    while [ $# -gt 0 ] ; do
        local -i invariant=$#
        case "$1" in
             # echo options
            -e|-E|-n)
                echo_opts+=("$1")
                shift
                ;;

            # our options
            -s | --stack-trace)
                use_stacktrace=1
                shift
                ;;
            --level)
                level="$2"
                shift 2
                ;;
            --default)
                default_message="$2"
                shift 2
                ;;
            *)
                # Not an option, stop processing
                break
                ;;
        esac

        if [ $# -eq $invariant ] ; then
            die "didn't shift args in $1 did you?"
        fi
    done

    local -a messages=("$@")
    if [ ${#messages[@]} -eq 0 ] ; then
        messages+=("${default_message}")
    fi

    (
        _log_print_level
        # cdonnelly 2017-03-02: No longer normalizing newlines in messages, it doesn't work well.
        # cdonnelly 2018-03-01: bash cannot echo an empty array in strict mode, so we have to check.
        local -a echo_args
        if [ ${#echo_opts[@]} -gt 0 ] ; then
            echo_args+=("${echo_opts[@]}")
        fi
        echo_args+=("${messages[@]}")
        echo "${echo_args[@]}"

        _log_stacktrace
    ) >&2
}

_logf() {
    # Parse out options
    local -i use_stacktrace=0
    local newline='\n'
    local level
    while [ $# -gt 0 ] ; do
        local -i invariant=$#
        case "$1" in
            -s | --stack-trace)
                use_stacktrace=1
                shift
                ;;
            --level)
                level="$2"
                shift 2
                ;;
            -n)
                # for parity with echo
                newline=''
                shift
                ;;
            *)
                # Not an option, stop processing
                break
                ;;
        esac

        if [ $# -eq $invariant ] ; then
            die "didn't shift args in $1 did you?"
        fi
    done

    local format="$1"
    shift 1

    #_log --level LOGLOG "format='${format}'" "args=[$@]"

    (
        _log_print_level
        # cdonnelly 2017-03-02: No longer normalizing newlines in messages, it doesn't work well.
        printf "${format}${newline}" "$@"
        _log_stacktrace
    ) >&2
}

_log_vars() {
    # Parse out log+echo options
    local -i use_stacktrace=0
    local level
    while [ $# -gt 0 ] ; do
        local -i invariant=$#
        case "$1" in
            # our options
            -s | --stack-trace)
                use_stacktrace=1
                shift
                ;;
            --level)
                level="$2"
                shift 2
                ;;
            *)
                # Not an option, stop processing
                break
                ;;
        esac

        if [ $# -eq $invariant ] ; then
            die "didn't shift args in $1 did you?"
        fi
    done

    (
        _log_print_level
        # cdonnelly 2017-03-02: No longer normalizing newlines in messages, it doesn't work well.
        declare -p "$@"
        _log_stacktrace
    ) >&2
}

# Public version of _log
log() {
    _log "$@"
}

# Public version of _logf
logf() {
    _logf "$@"
}

# Public version of _log_vars
log_vars() {
    _log_vars --level NOTICE "$@"
}

is_warn() {
    [ ${log_level} -ge 0 ]
}

warn() {
    if is_warn; then
        _log --level WARN --default "Something's wrong" "$@"
    fi
}

warnf() {
    if is_warn; then
        _logf --level WARN "$@"
    fi
}

warn_vars() {
    if is_warn; then
        _log_vars --level WARN "$@"
    fi
}

is_notice() {
    is_warn
}

notice() {
    if is_notice; then
        _log --level NOTICE "$@"
    fi
}

is_info() {
    [ ${log_level} -ge 1 ]
}

info() {
    if is_info; then
        _log --level INFO "$@"
    fi
}

infof() {
    if is_info; then
        _logf --level INFO "$@"
    fi
}

info_vars() {
    if is_info; then
        _log_vars --level INFO "$@"
    fi
}

is_debug() {
    [ ${log_level} -ge 2 ]
}

debug() {
    if is_debug; then
        _log --level DEBUG "$@"
    fi
}

debugf() {
    if is_debug; then
        _logf --level DEBUG "$@"
    fi
}

debug_vars() {
    if is_debug; then
        _log_vars --level DEBUG "$@"
    fi
}

is_trace() {
    [ ${log_level} -ge 3 ]
}

trace() {
    if is_trace; then
        _log --level TRACE "$@"
    fi
}

tracef() {
    if is_trace; then
        _logf --level TRACE "$@"
    fi
}

trace_vars() {
    if is_trace; then
        _log_vars --level TRACE "$@"
    fi
}

get_log_level() {
    local getopt=`getopt -o in --long id,name \
        -n $(basename "$0") -- "$@"`

    if [ $? != 0 ] ; then
        die "Terminating..."
    fi

    # Note the quotes around the variable: they are essential!
    eval set -- "${getopt}"

    local format='id'
    while true; do
        local -i invariant=$#
        case "$1" in
            -i | --id)
                format=id
                shift
                ;;
            -n | --name)
                format=name
                shift
                ;;

            --) shift ; break ;;
            *)  break ;;
        esac

        if [ $# -eq $invariant ] ; then
            die "didn't shift args in $1 did you?"
        fi
    done

    case "${format}" in
        id)
            echo "${log_level}"
            ;;
        name)
            case "${log_level}" in
                0) echo WARN
                    ;;
                1) echo INFO
                    ;;
                2) echo DEBUG
                    ;;
                3) echo TRACE
                    ;;
                4) echo VERBOSE
                    ;;
                -*)
                    echo OFF
                    ;;
                *)
                    echo ALL
                    ;;
            esac
            ;;
    esac
}

set_log_level() {
    local -l value="$1"
    case "${value}" in
        [0-9])
            log_level="${value}"
            ;;
        fatal)        log_level=-2 ;;
        error)        log_level=-1 ;;
        warn|warning) log_level=0 ;;
        info)         log_level=1 ;;
        debug)        log_level=2 ;;
        trace)        log_level=3 ;;
        verbose)      log_level=4 ;;
        *)
            warn "Unsupported log level: ${value}"
            ;;
    esac
}

####################################################################################################################################
# Exception handling
####################################################################################################################################

declare -i help=0

die() {
    # Parse out echo options
    _log --default "Died" "$@"
    exit 255
}

die_need_help() {
    die -e "$@\nTry \`$(basename "${0}") --help\` for more information."
}

confess() {
    die --stack-trace "$@"
}

####################################################################################################################################
# Dry Run
####################################################################################################################################

declare -i dry_run=0

is_dryrun() {
    [ ${dry_run} -gt 0 ]
}

runcmd() {
    local -i always=0
    if [ "$1" == '--always' ] ; then
        # always run the command
        always=1
        shift
    fi

    if ! is_dryrun ; then
        "$@"
        return $?
    fi

    # dry-run
    (
        local readonly needs_quote_regex='[^[:alnum:]=_.,\-]'
        echo -n '[DRYRUN]'
        for arg in "$@"; do
            case "${arg}" in
                # special chars: fall through
                '|') ;;
                *)
                    if [[ "${arg}" =~ ${needs_quote_regex} ]] ; then
                        echo -n " '${arg}'"
                        continue
                    fi
                    ;; # fall through
            esac

            # plain echo
            echo -n " ${arg}"
        done
        echo ''
    ) >&2

    if [ ${always} -ne 0 ] ; then
        "$@"
        return $?
    fi

    return 0
}

####################################################################################################################################
# Glob
####################################################################################################################################

glob_expand() {
    local x
    local abs
    for x in "$@"; do
        abs=$(readlink -f "${x}")
        eval ls -1d "${abs}" 2> /dev/null
    done
}

####################################################################################################################################
# Formatting
####################################################################################################################################

format_bytes() {
    # numfmt does it, except numfmt isn't on the ancient RHEL versions we use.
    if numfmt --to=iec "$@" 2>/dev/null; then
        return 0
    fi

    # fallback: numfmt doesn't exist.
    if [ $# -eq 0 ] ; then
        echo >&2 "format_bytes: must specify a value"
        return 1
    fi

    local -i num
    for num in "$@"; do
        local -i num="${1:?"Must specify a value"}"
        local -i div=${num} suffix_id=0 div_by=1

        while [ ${div} -ge 1024 ] ; do
            ((suffix_id++))
            ((div_by *= 1024))
            ((div /= 1024))
        done

        local suffix
        case ${suffix_id} in
            0)
                # short-circuit out
                echo "${num}"
                return 0
                ;;
            1) suffix='K' ;;
            2) suffix='M' ;;
            3) suffix='G' ;;
            4) suffix='T' ;;
            5) suffix='P' ;;
            # cdonnelly 2017-01-26: awk on RHEL 6.x can't handle numbers somewhere north of 7.0 exebytes, don't support
            #6) suffix='E' ;;
            #7) suffix='Z' ;;
            *)
                echo >&2 "Value too large to be converted: '${num}'"
                ;;
        esac

        local -i scale=0
        if [[ ${div_by} -gt 1 && ${div} -lt 10 ]] ; then
            # need 1 decimal point of scale
            scale=1
        fi

        # to match numfmt we round UP
        local result=$(awk "BEGIN { a=${num}/${div_by}; printf \"%.${scale}f\", (a == int(a) ? a : int(a) + exp(log(10) * -${scale})) }")
        echo "${result}${suffix}"
    done
}

####################################################################################################################################

password_prompt() {
    local varname="${1:-password}"
    local prompt="${2:-Password:}"

    # If the password var is already set, exit
    local varvalue;
    eval varvalue=\$${varname}
    if [ -n "${varvalue}" ] ; then
        return 0
    fi

    stty -echo      # turn off screen echo
    echo -n "${prompt} "
    read ${varname}
    stty echo       # restore echo
    echo ""
}

version_is() {
    local op l_version r_version
    case $# in
        0 | 1)
            warn "version_is: Not enough arguments"
            return 255
            ;;
        2)
            # assumes equality
            op='-eq'
            l_version="$1"
            r_version="$2"
            ;;
        *)
            op="$2"
            l_version="$1"
            r_version="$3"
            ;;
    esac

    debug "'${l_version}' ${op} '${r_version}'"

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
            warn "unknown/unsupported operator ${op}.  Continuing though we may have problems"
            ;;
    esac



    local -a l_versinfo=( ${l_version//[().-]/ } ) # split on all possible delimiters
    local -a r_versinfo=( ${r_version//[().-]/ } ) # split on all possible delimiters
    local -i i
    local -i last_was_eq=0
    for i in "${!r_versinfo[@]}"; do
        last_was_eq=0
        debug "    => cmp: $i: ${l_versinfo[i]} ${op} ${r_versinfo[i]}"

        # BASHCRAP: have to compare and check $? this way, doing an if statement doesn't preserve value of $?
        [ ${l_versinfo[i]} ${op} ${r_versinfo[i]} ] 2>/dev/null
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
                        debug "        => true (ne)"
                        return 0
                        ;;
                    '-le' | '-ge')
                        if [[ ${l_versinfo[i]} -ne ${r_versinfo[i]} ]] ; then
                            debug "        => true (ne)"
                            return 0
                        fi
                        ;;
                esac

                # Keep checking
                debug "        => true (eq)"
                continue
                ;;

            1)
                # fall through
                ;;
            2)
                # numeric op failed.  Try string ops
                if [[ ${#string_ops[@]} -eq 0 ]] ; then
                    warn "Numeric comparison failed and no string operations exist for operator ${op}"
                    return 2
                fi

                trace "        => as string: ${l_versinfo[i]} ${string_ops[*]} ${r_versinfo[i]}"

                local sop
                local -i found=0
                for sop in "${string_ops[@]}" ; do
                    if [ "${l_versinfo[i]}" ${sop} "${r_versinfo[i]}" ] ; then
                        found=1
                        break
                    fi
                done

                if [ ${found} -eq 0 ] ; then
                    debug "        => false (string)"
                    return 1
                fi

                case "${op}" in
                    '-eq')
                        # keep checking
                        ;;
                    '-ne' | '-lt' | '-gt')
                        # we succeeded outright
                        debug "        => true (string-ne)"
                        return 0
                        ;;
                    '-le' | '-ge')
                        if [[ ${l_versinfo[i]} -ne ${r_versinfo[i]} ]] ; then
                            debug "        => true (string-ne)"
                            return 0
                        fi
                        ;;
                esac

                debug "        => true (string-eq)"
                continue
                ;;
            *)
                warn "Unexpected: comparison result was $?"
                return 2
                ;;
        esac


        if [[ "${op}" != '-ne' && ${l_versinfo[i]} -eq ${r_versinfo[i]} ]] ; then
            # our op is not -eq or -ne, and failed, but the values are equal.  keep checking
            debug "        => false, but equal and ${op} != -ne"
            last_was_eq=1
            continue
        fi

        debug "        => false"
        debug "fail"
        debug_vars i l_versinfo op r_versinfo last_was_eq
        return 1
    done

    # return TRUE (0) if last was a real compare, not an "equality and keep going" compare
    debug "maybe success (${last_was_eq})"
    debug_vars i l_versinfo op r_versinfo last_was_eq
    return ${last_was_eq}
}

bash_version_is() {
    local op r_version
    case $# in
        0)
            echo >&2 "bash_version_is: Not enough arguments"
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

    local -a r_versinfo=( ${r_version//[().-]/ } ) # split on all possible delimiters
    local -i i
    local -i last_was_eq=0
    for i in "${!r_versinfo[@]}"; do
        last_was_eq=0
        debug "cmp: $i: ${BASH_VERSINFO[i]} ${op} ${r_versinfo[i]}"
        if [ ${BASH_VERSINFO[i]} ${op} ${r_versinfo[i]} ] ; then
            # our op worked
            debug '        => true'
            continue
        elif [[ "${op}" != '-ne' && ${BASH_VERSINFO[i]} -eq ${r_versinfo[i]} ]] ; then
            # our op is not -eq or -ne, and failed, but the values are equal.  keep checking
            debug "        => false, but equal and ${op} != -ne"
            last_was_eq=1
            continue
        fi
        debug '        => false (FAIL)'
        debug_vars i r_versinfo op BASH_VERSINFO last_was_eq
        return 1
    done

    # return TRUE (0) if last was a real compare, not an "equality and keep going" compare
    debug "success"
    debug_vars i r_versinfo op BASH_VERSINFO last_was_eq
    return ${last_was_eq}
}

bash_require() {
    if ! bash_version_is -ge "$1" ; then
        die "bash ${1} or higher required."
    fi
}

####

is_run_from_shell() {
    # cdonnelly 2017-01-20: This leaves a LOT to be desired.
    # It only works on Cygwin, and only means "is not run from bash".
    [ $PPID -ne 1 ]
}

press_any_key() {
    local msg="${1:-Press any key to continue...}"
    read -n 1 -s -p "${msg}"
}


