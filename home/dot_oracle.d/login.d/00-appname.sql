/*

Gets the app name.

*/

define _X_APP_NAME = 'unknown'
column APP_NAME new_value _X_APP_NAME

--@see http://asktom.oracle.com/pls/asktom/f?p=100:11:0::::P11_QUESTION_ID:114412348062
select lower(regexp_replace(s.PROGRAM, '\.exe$', '', 1, 0, 'i')) as APP_NAME
  from V$SESSION s
 where s.AUDSID = sys_context('userenv', 'sessionid')
   and rownum = 1
/