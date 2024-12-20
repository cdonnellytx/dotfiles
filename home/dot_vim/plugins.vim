" Syntaxes
Plug 'cdonnellytx/splunk.vim'
Plug 'elzr/vim-json'
Plug 'jsmulrow/vim-githublink'
Plug 'juliosueiras/cakebuild.vim'
Plug 'martinda/Jenkinsfile-vim-syntax'
Plug 'neoclide/jsonc.vim'
Plug 'pprovost/vim-ps1'
Plug 'sillyotter/t4-vim'
Plug 'rhysd/vim-gfm-syntax'

" editorconfig/editorconfig-vim: not needed since 9.0.1799
if !has("patch-9.0.1799")
    " @see https://github.com/editorconfig/editorconfig-vim?tab=readme-ov-file#bundled-versions
    Plug 'editorconfig/editorconfig-vim'
endif

" Themes
Plug 'tomasiser/vim-code-dark'

" Utils
Plug 'psliwka/vim-dirtytalk', { 'do': ':DirtytalkUpdate' } " programming spell checker
Plug 'tpope/vim-fugitive'                                  " Git helpers
Plug 'guns/xterm-color-table.vim'
if v:version >= 810 && g:os_type == "windows"
    Plug 'iamcco/markdown-preview.nvim', { 'do': { -> mkdp#util#install() }}
endif


" how to add a GHE plugin.  Note this isn't a real one.
"Plugin 'git@ghe.coxautoinc.com:foo/bar'

