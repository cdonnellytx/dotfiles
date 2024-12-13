--Set time zone
alter session set time_zone = 'US/Central';

alter session set nls_date_format = 'YYYY-MM-DD HH24:MI:SS';
alter session set nls_time_format = 'HH24:MI:SS';
alter session set nls_time_tz_format = 'HH24:MI:SS TZR';
--cdonnelly 2018-11-08: *someone* broke something with DDL triggers. Changing NLS_TIMESTAMP_FORMAT to not have DD-MON-RR causes every DDL statement to fail.
--alter session set nls_timestamp_format = 'YYYY-MM-DD HH24:MI:SSXFF';
alter session set nls_timestamp_tz_format = 'YYYY-MM-DD HH24:MI:SSXFF TZR';
