" Vim syntax file workarounds
set textwidth=0
set spell

" - is allowed in keywords

" GitHub says 72, not 50.
" @see https://stackoverflow.com/questions/2290016/git-commit-messages-50-72-formatting
syn clear   gitcommitSummary
syn match   gitcommitSummary	"^.*\%<73v." contained containedin=gitcommitFirstLine nextgroup=gitcommitOverflow contains=@Spell

"syn keyword gitcommitTrailerName Author Committer Date Co-authored-by Signed-off-by

" can't get this contained stuff to work.
syn keyword gitcommitTrailerName contained Author Committer Date Co-authored-by Signed-off-by
syn region  gitcommitTrailer	matchgroup=gitCommitTrailerName start=/^\@<=\%(Author\|Committer\|Co-authored-by\|Signed-off-by\):/ end=/$/ keepend oneline fold
syn region  gitcommitAuthor	matchgroup=gitCommitHeader start=/\%(^# \)\@<=\%(Author\|Committer\|Co-authored-by\|Signed-off-by\):/ end=/$/ keepend oneline contained containedin=gitcommitComment transparent

hi def link gitcommitTrailerName	Identifier
hi def link gitcommitTrailer		Constant

""""""""""""""""
" autosquash
""""""""""""""""

syn match   gitcommitSquash "\v^squash!" contained containedin=gitcommitSummary skipwhite
syn match   gitcommitFixup  "\v^fixup!"  contained containedin=gitcommitSummary skipwhite
syn match   gitcommitAmend  "\v^amend!"  contained containedin=gitcommitSummary skipwhite

hi def link gitcommitSquash         Special
hi def link gitcommitFixup          Special
hi def link gitcommitAmend          Special

" Disabling b/c 99% of repos I use do NOT follow this.
"" Conventional commit syntax support
"" https://www.reddit.com/r/vim/comments/dj37wt/plugin_for_conventional_commits/f40sija/?utm_source=reddit&utm_medium=web2x&context=3
""inoreabbrev <buffer> BB BREAKING CHANGE:
"nnoremap    <buffer> i  i<C-r>=<sid>commit_type()<CR>
"
"fun! s:commit_type()
"  call complete(1, ['fix: ', 'feat: ', 'refactor: ', 'docs: ', 'test: '])
"  nunmap <buffer> i
"  return ''
"endfun
