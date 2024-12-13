#!/usr/bin/env bash
#
# Install PowerShell on macOS.
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
# Main
#
function main() {
    if test_command pwsh ; then
        return 0
    fi

    warn "${0}: Not yet implemented (Darwin)"
}

main