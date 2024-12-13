#!/usr/bin/env bash
#
# Fix Synology ACLs.
#

function main() {
    # Only run on Synology.
    if [[ -n "${os_subtype}" && "${os_subtype}" -ne "Synology" ]] ; then
        return 0
    fi

    synoacltool=$(command -v synoacltool | head -1)

    if [ -z "${synoacltool}" ] ; then
        return 0
    fi

    # Expose these directories to 'backup ops' group.
    for dir in ~/.gnupg ~/.ssh ; do
        synoacltool -add "${dir}" 'owner:*:allow:rwxpdDaARWcCo:fd--'
        synoacltool -add "${dir}" 'group:backup ops:allow:r-x---a-R-c--:fd--'
    done
}

main
