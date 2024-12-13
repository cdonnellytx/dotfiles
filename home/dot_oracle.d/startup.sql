
/*
sqlcl settings

ORACRAP aplenty!

- It still pulls in login.sql too, and I don't know how to make things only run in sqlplus. startup.sql at least is only run by sqlcl.
    - Except that it ignores the 
- Colors are limited to named colors, unelss I missed something abut RGB.


References:

- https://www.thatjeffsmith.com/archive/2021/10/oracle-sqlcl-all-the-pretty-colors-for-your-console/
- https://krisrice.io/2015-10-13-sqlcl-oct-13th-edition/

*/
set termout off

@@startup.d/11-chrome.sql
@@startup.d/20-syntax-highlighting.sql

set termout on
