/*

login.sql used by:

- SQL*Plus
- SQL Developer
- SQLcl
- TOAD (partially)

*/
set termout off

@@login.d/00-appname.sql
@@login.d/50-timezone.sql
@@login.d/90-prompt.&_X_APP_NAME..sql
@@login.d/99-dbms_metadata.sql
@@login.d/99-format.&_X_APP_NAME..sql

set termout on
set timing on

set editfile cdonnelly_working.sql

