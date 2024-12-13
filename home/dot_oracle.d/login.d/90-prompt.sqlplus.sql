/*

Prompt theme (SQL*Plus version).

*/

----------------------------------------
-- Prompt options
----------------------------------------

--While not as fancy as the oh-my-posh time widget, this at least doesn't count toward the extremely small SQL*Plus sqlprompt size (50 chars).
set time on

-----------------------------------------------------
-- Colors
-----------------------------------------------------

--Did I mention SQL*Plus' sqlprompt is *painfully* small? 50 bytes?
--Also it doesn't resolve nested
define __empty = ''
define __prompt_session_color = '&__csi.32;1m'
define __sqlprompt = "&__prompt_session_color.&_user@&__empty.&_CONNECT_IDENTIFIER&__csi.0m> "

column len new_value __sqlprompt_length
column esc new_value __sqlprompt_esc
select length('&__sqlprompt') as len, regexp_replace('&__sqlprompt', chr(27), '\e') as esc
  from dual
/

set sqlprompt "&__sqlprompt"

