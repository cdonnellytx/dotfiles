" SAVED PATTERNS
" - To save the current search register, edit this file and add the following line:
"   let MyRegExName = '<C-R>/'
"   (or use q: in normal mode to see command history)
" - To use a saved regex:
"   / <C-R> = MyRegExName
" @see https://stackoverflow.com/questions/2201174/save-commonly-used-regex-patterns-in-vim

let RegexConflictBlock = '\v^([<=>|])\1{6}'
let RegexCsprojAddBlankLines = '\v\>\n(\s*\<(PropertyGroup|ItemGroup|Import|\/Project))'
let RegexOracleJsonValue = '\v^\s+\/\*\*\n\s+\* `([^`]+)`.*\n(\s+\*(\s+.*)?\n)+\s*\*\/\n\s*(\w+)\s+.*'

