" Vim syntax file workarounds

" Head: Match the new style (v5.00 onward)
syn match registryHead		"^Windows Registry Editor Version [0-9][0-9.]*$"

" Subkey: workaround bug in Vim syntax file that kills comment highlighting
syn clear registrySubKey
syn match registrySubKey		"^\".*\"="
" Default value
syn match registrySubKey		"^@="  " NOT ^\@=

" vim:ts=8
