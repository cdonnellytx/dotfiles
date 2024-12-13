let s:dash132 = "------------------------------------------------------------------------------------------------------------------------------------"
let s:promptstar="prompt ************************************************************************************************************************************"
let s:empty = ""        " I'm sure there's a better way to do this.


function! s:fileprompt(name)
    let l:prompt="prompt " . a:name
    put! =s:dash132
    put =l:prompt
    put =s:dash132
    put =s:empty    " extra blank line so content doesn't run up against it...
endfunction

function! plsql#inline()
    let l:text=getline('.')
    let l:filename=substitute(substitute(l:text, '^@@\?', '', ''), '\s\+$', '', '')
    if empty(l:filename)
        echoerr "ERROR: No filename was found."
    endif

    if has("win32unix") && !match(l:filename, '^/')
        " Cygwin: need to convert to UNIX path.
        let l:filename = substitute(l:filename, '\\', '/', 'g') " replace the slashes -- seems to work for any path
    endif

    if empty(glob(l:filename))
        echoerr "ERROR: file not found: " . l:filename
        return 1
    elseif !filereadable(l:filename)
        echoerr "ERROR: file not readable: " . l:filename
    endif

    "echo "text:     " . l:text
    "echo "filename: " . l:filename

    " Delete current line and output new text.

    del
    call s:fileprompt(l:text)
    exec "read " . fnameescape(l:filename)
endfunction
