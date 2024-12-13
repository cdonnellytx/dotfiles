/*

sqlcl prompt theme.

Known issues
============

ORACRAP galore.

- DATE: there is no way to show the current date/time.
    - _DATE doesn't ever change like it does in SQL*Plus, it will always be the (start? connect?) date.
      Not even when running a SQL command.
    - SET TIME ON, if set _anywhere_ in startup, will cause time to be printed twice. I don't see a way around this.
        - One copy never changes, the other only changes if you run a command.
- Newlines in prompts are ignored, you cannot have multiline prompts.

*/
define __powerline = ''        --U+E0B0  nf-pl-left_hard_divider
define __nf_md_database = '󰆼'   --U+F01BC nf-md-database

define __prompt_session = "@|green,bold _USER@_CONNECT_IDENTIFIER |@"
define __prompt_symbol = '@|fg_black,bold,bg_red,faint,negative_on " &__nf_md_database. "|@'

--Now do transitions
define __px_prompt_BEGIN_session  = ''
define __px_session_symbol = '@|fg_black,bold,bg_black,faint,negative_on &__powerline.|@'
define __px_symbol_END = '@|fg_black,faint,bg_black,bold &__powerline.|@'

set sqlprompt "&__px_prompt_BEGIN_session.&__prompt_session&__px_session_symbol&__prompt_symbol&__px_symbol_END. "

